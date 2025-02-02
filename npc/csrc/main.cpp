#include <common.h>
// ============ verilator sim ===========
#define MAX_SIM_TIME 15000000
uint64_t sim_time = 0;
unsigned long long sim_cycle= 0;
unsigned long long debug_inst = 0;
#define DEBUG_SKIP 0
//361307
// 一些导入的接口
void init_device();

// =============== DPI-C ================
// Get Registers
uint64_t *cpu_gpr = NULL;

extern "C" void get_regs(const svOpenArrayHandle r)
{
  cpu_gpr = (uint64_t *)(((VerilatedDpiOpenVar*)r) -> datap());
}

//Ebreak
void debug_exit(int status);
bool ebreak_ok = false;
void ebreak()
{
  ebreak_ok = true;
  
}
// 同步总线访问
#ifdef CONFIG_ITRACE
//程序profling的接口
bool arbiter_exec = false;
void arbiter_wait(){
  //printf("1\n");
  arbiter_exec = true;
}
bool icache_exec = false;
void icache_wait(){
  //printf("1\n");
  icache_exec = true;
}
#endif
bool difftest_ok = false;
void difftest_valid(){
  //printf("1\n");
  difftest_ok = true;
}
// =========================== Debug ===========================
// =============== Itrace ===============

#define SIZE_RINGBUF 16
#define LEN_RINGBUF 256
int ring_pos = SIZE_RINGBUF - 1;
char ringbuf[SIZE_RINGBUF][LEN_RINGBUF];

void itrace_record(uint64_t pc)
{
  if (pc < MEM_BASE) return;
  // ring_pos
  if (ring_pos == SIZE_RINGBUF - 1) ring_pos = 0;
  else ring_pos = ring_pos + 1;
  // fetch_inst
  uint8_t *pt = guest_to_host(pc);
  uint8_t *inst = (uint8_t*)malloc(sizeof(uint8_t) * 4);
  for (int i = 0; i < 4; ++i) {
    inst[i] = (*pt++);
  }
  // prepare buffer
  char *p = ringbuf[ring_pos];
  p += sprintf(p, "0x%016lx:", pc);
  for (int i = 0; i < 4; ++i) {
    p += sprintf(p, " %02x", inst[i]);
  }
  p += sprintf(p, "\t");
  // disasm
  disassemble(p, pc, inst, 4);
}
#ifdef CONFIG_ITRACE
// Using IRingBuf as Itrace
// The following content are copied from nemu, until itracer().
void itrace_output()
{
  printf("========== Itrace Ringbuf ==========\n");
  for (int i = 0; i < SIZE_RINGBUF; ++i) {
    if (ring_pos == i) printf("--->");
    else printf("    ");
    printf("%s\n", ringbuf[i]);
  }
  printf("====================================\n");
}
#endif
// ========================= Difftest ==========================
#ifdef CONFIG_DIFFTEST
enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };
void (*ref_difftest_memcpy)(uint32_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL;

const char* am_home;
void init_difftest() {
  const char* nemu_home = getenv("NEMU_HOME");
  // 确保环境变量存在
  if (nemu_home == NULL) {
      printf("Error: Environment variable NEMU_HOME not set\n");
      return;
  }
  char ref_so_file[256]; // 定义一个足够大的字符数组来存储路径
  // 将 am_home 的值拷贝到 image_path
  strcpy(ref_so_file, nemu_home);
  // 进行路径拼接
  strcat(ref_so_file, "/build/riscv64-nemu-interpreter-so");
  printf("diff_init   ok\n");
  assert(ref_so_file != NULL);

  void *handle;
  handle = dlopen(ref_so_file, RTLD_LAZY);
  assert(handle);

  ref_difftest_memcpy = (void (*)(uint32_t addr, void *buf, size_t n, bool direction))(dlsym(handle, "difftest_memcpy"));
  assert(ref_difftest_memcpy);

  ref_difftest_regcpy = (void (*)(void *dut, bool direction))(dlsym(handle, "difftest_regcpy"));
  assert(ref_difftest_regcpy);

  ref_difftest_exec = (void (*)(uint64_t n))(dlsym(handle, "difftest_exec"));
  assert(ref_difftest_exec);

  ref_difftest_raise_intr = (void (*)(uint64_t NO))(dlsym(handle, "difftest_raise_intr"));
  assert(ref_difftest_raise_intr);

  void (*ref_difftest_init)() = (void (*)())(dlsym(handle, "difftest_init"));
  assert(ref_difftest_init);

  ref_difftest_init();
  ref_difftest_memcpy(MEM_BASE, pmem, img_size, DIFFTEST_TO_REF);
  ref_difftest_regcpy(cpu_gpr, DIFFTEST_TO_REF);
}
void exec_once();
void checkregs(uint64_t *ref_regs)
{
  IFDEF(DEBUG_DIFFTRACE, printf("diff_log: Difftest pc = 0x%016lx inst = 0x%016x\n", cpu_gpr[32],dut->now_inst));
  for (int i = 0; i <= 36; ++i) {
    if (ref_regs[i] != cpu_gpr[i]) {

#ifndef CONFIG_ITRACE
//仅在二周期时是完全适用的，依赖于取指令先于目前执行的指令取出上一级的指令
      printf("=============== error inst ========================\n");
      printf("注:错误在跳转指令后时,无法获得正确的错误pc,需要以itrace为参考\n");
      itrace_record(dut->now_addr - 4);
      printf("%s\n", ringbuf[0]);
#endif

      printf("================= reg diff ========================\n");
      printf("Error: Difftest failed at reg %d, pc = 0x%016lx inst = 0x%016x\n", i, dut->now_addr,dut->now_inst);
      for (int j = 0; j <= 32; ++j) {
        if (cpu_gpr[j] != ref_regs[j]) printf(COLOR_RED);
        printf("reg %02d: dut = 0x%016lx, ref = 0x%016lx\n", j, cpu_gpr[j], ref_regs[j]);
        if (cpu_gpr[j] != ref_regs[j]) printf(COLOR_NONE);
      }
      printf("================= csr diff ======================\n");
      if(cpu_gpr[33] != ref_regs[33]) printf(COLOR_RED); else printf(COLOR_NONE);
      printf("mtvec   %02d: dut = 0x%016lx, ref = 0x%016lx\n", 33, cpu_gpr[33], ref_regs[33]);
            if(cpu_gpr[34] != ref_regs[34]) printf(COLOR_RED); else printf(COLOR_NONE);
      printf("mepc    %02d: dut = 0x%016lx, ref = 0x%016lx\n", 34, cpu_gpr[34], ref_regs[34]);
            if(cpu_gpr[35] != ref_regs[35]) printf(COLOR_RED); else printf(COLOR_NONE);
      printf("mstatus %02d: dut = 0x%016lx, ref = 0x%016lx\n", 35, cpu_gpr[35], ref_regs[35]);
            if(cpu_gpr[36] != ref_regs[36]) printf(COLOR_RED); else printf(COLOR_NONE);
      printf("mcause  %02d: dut = 0x%016lx, ref = 0x%016lx\n", 36, cpu_gpr[36], ref_regs[36]);
      printf(COLOR_NONE);
      debug_exit(1);
    }
  }
}

uint64_t ref_regs[36];
void difftest_exec_once()
{
  if (is_skip_ref) {
    //printf("is_skip_ref= %d\n",is_skip_ref);
    //防止递归失败的false设置，放在后面会被覆盖
    //is_skip_ref = false;
    //exec_once();

//一个冒险的开关当开启这里时，会跳过连续访问外设的diff写reg覆盖，但会将访问后一条指令的结果直接写入参考模型，这是一个对正确性的隐患。（提升效果2~3倍）
    while(is_skip_ref){
    is_skip_ref = false;
    #ifdef CONFIG_ITRACE
    itrace_record(dut->now_addr);
// 会增加一定的性能负担，且这个类型一旦溢出会导致程序被杀死
    debug_inst++;
#endif
      while(difftest_ok == false){
      exec_once();
       }
      difftest_ok = false;
    }

    
    ref_difftest_regcpy(cpu_gpr, DIFFTEST_TO_REF);
    //printf("time-last-is_skip_ref= %d\n",is_skip_ref);
    //printf("%lx\n",cpu_gpr[32]);
    //printf("yes %lx\n",cpu_gpr[32]);
    return;
  }
  else{
  //printf("nemu-is_skip_ref= %d\n",is_skip_ref);
  //printf("no  %lx\n",cpu_gpr[32]);
  ref_difftest_exec(1);
  ref_difftest_regcpy(ref_regs, DIFFTEST_TO_DUT);
  //printf("is_skip_ref= %d\n",is_skip_ref);
  checkregs(ref_regs);
  return;
  }
}

#endif
void exec_once();
void debug_exit(int status)
{
printf("仿真时钟周期约为=%.3f m 有效指令=%lld k ipc=%.3f\n", (double)sim_cycle/1000000, debug_inst/1000, (double)debug_inst/sim_cycle);
  
#ifdef CONFIG_GTKWAVE
  m_trace -> close();
#endif
#ifdef CONFIG_ITRACE
  if (status != 0) itrace_output();
#endif
  if (status == 0) 
  {
  puts("\33[1;32mSim Result: HIT GOOD TRAP\33[0m");
  exit(EXIT_SUCCESS);
  }
  else 
  {
  puts("\33[1;31mSim Result: HIT BAD TRAP\33[0m");
  exit(EXIT_FAILURE);
  }

}

// ========================= Functions =========================
//将指令读入到mem中(附带打印内存功能)
void load_image()
{
  const char* IMG = getenv("IMG");
  //const char* IMG = "/home/zyx/exam-test/ysyx-exam/nanos-lite/build/nanos-lite-riscv64-nemu.bin";
  // 确保环境变量存在
  if (IMG == NULL) {
      printf("Error: Environment variable IMG not set\n");
      return;
  }
  assert(IMG != NULL);
  FILE *fp = fopen(IMG, "rb");
  assert(fp);
  fseek(fp, 0, SEEK_END);
  img_size = ftell(fp);
  fseek(fp, 0, SEEK_SET);
  printf("The image is %s, size = %lld\n", IMG, img_size);
  int ret = fread(pmem, img_size, 1, fp);
  fclose(fp);
  assert(ret);
}
//gtkwave的波形生成测试
void gtkwave()
{
    Verilated::traceEverOn(true);
    dut->trace(m_trace, 99);
    m_trace->open("top.vcd");
}
//cpu复位信号控制
void cpu_reset()
{
  dut -> clk = 0;
  dut -> rst_n = 1;
  dut -> eval();
#ifdef CONFIG_GTKWAVE
  if(debug_inst >= DEBUG_SKIP){
  m_trace -> dump(sim_time++);
  }
#endif
  dut -> clk = 1;
  dut -> rst_n = 1;
  dut -> eval();
#ifdef CONFIG_GTKWAVE
  if(debug_inst >= DEBUG_SKIP){
  m_trace -> dump(sim_time++);
  }
#endif
  dut -> rst_n = 0;
}
//cpu运行一次
void exec_once()
{
#ifdef COUNT_IPC
  sim_cycle++;
#endif

  dut->clk = 0;
  dut -> eval();
#ifdef CONFIG_GTKWAVE
  if(debug_inst >= DEBUG_SKIP){
  m_trace -> dump(sim_time++);
  }
#endif
  dut->clk = 1;
  dut -> eval();
#ifdef CONFIG_GTKWAVE
  if(debug_inst >= DEBUG_SKIP){
  m_trace -> dump(sim_time++);
  }
#endif
}
/*
static void execute(uint64_t n) {
    for (;n > 0; n --) {
        exec_once();// 执行一次
        #ifdef CONFIG_DIFFTEST
            difftest_exec_once();
        #endif
    }
}
*/
//主函数部分
int main(int argc, char** argv, char** env) {
    printf("++++++++start+++++++\n");

#ifdef  CONFIG_GTKWAVE 
    gtkwave();
#endif
    IFDEF(CONFIG_DEVICE, init_device());
    load_image();
    cpu_reset();
    init_disasm("riscv64-pc-linux-gnu");
//2流水线择在这里将cpu先跑一次，不可放在‘init_disasm（）’初始前
// 这一段的状态是定位到第一条指令需要diff的时刻，然后把这个时刻的cpu状态传给nemu进行初始化，以此来定位以后的错误
      while(difftest_ok == false){
      exec_once();
       }
       difftest_ok = false;

    //这一段的作用是将cpu的初始状态对齐到nemu中，所以在改进icache后，需要注意difftest肯也需要改进
//    icache_exec = false;
    //difftest_ok = false;
#ifdef CONFIG_DIFFTEST
  init_difftest();
#endif
    while (1) {
      IFDEF(CONFIG_DEVICE, device_update());

      while(difftest_ok == false){
      exec_once();
       }
       difftest_ok = false;
       //debug_exit(1);
#ifdef CONFIG_ITRACE
    itrace_record(cpu_gpr[32]);
    debug_inst++;
#endif
       if(ebreak_ok){
        exec_once();
        printf("ebreak:%lx,%lx\n",cpu_gpr[10],dut->now_addr) ;
        debug_exit(cpu_gpr[10]);
       }
#ifdef CONFIG_DIFFTEST
        // 遇到越界时候可以在这里打断点，对于错误的pc+4（适配仿真环境+保持尽可能多的数据）
        /*if(cpu_gpr[32] == (uint64_t)0x0000000080004f64)
        {
           debug_exit(1);
        }
        */
        difftest_exec_once();
#endif
    }
}
