#include <common.h>
#include "syscall.h"//syscall.h在lite和apps里都声明了。注意统一性
#include <fs.h>//关于系统调用函数的实现
#include <sys/time.h>//时间结构体库
#include <am.h>
#include <proc.h>

extern void naive_uload(PCB *pcb, const char *filename);

//向am获取当前时间并写入结构体中的函数
static size_t sys_gettimeofday(const void *time_struct) {
  struct timeval *tv = (struct timeval *)time_struct;
  size_t time = io_read(AM_TIMER_UPTIME).us;
  // 微秒到秒差10^6
  tv->tv_usec = (time % 1000000);//存储当前时间的微秒数
  tv->tv_sec  = (time / 1000000);//存储当前时间的秒数
  return 0; 
}

static size_t sys_sbrk(size_t addr) {
  return 0;
}

void do_syscall(Context *c) {
  uintptr_t a[5];
  a[0] = c->GPR1;
  a[1] = c->GPR2;
  a[2] = c->GPR3;
  a[3] = c->GPR4;
  /* a[4]保存返回值， */
  a[4] = 0;
  switch (a[0]) {
    case SYS_exit:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_exit   . %d %d %d %d\n",a[0],a[1],a[2],a[3]);
#endif
      //naive_uload(NULL, (const char *)" bin/menu"); 
      halt(a[1]);
      break;

    case SYS_yield:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_yield  . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      yield();
      break;
      
    case SYS_open :
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_open   . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      a[4] = fs_open(( char *)a[1], a[2], a[3]);
      break;

    case SYS_read:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_read   . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      a[4] = fs_read(a[1], (const void *)a[2], a[3]);
      break;

    case SYS_write:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_write  . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      a[4] = fs_write(a[1], (void *)a[2], a[3]);
      break;

    case SYS_close:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_close  . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      a[4] = fs_close(a[1]);
      break;

    case SYS_lseek:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_lseek  . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif
      a[4] = fs_lseek(a[1], a[2], a[3]);
      break;

    case SYS_brk:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_brk    . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif 
      a[4] = sys_sbrk(a[1]); 
      break;

      case SYS_execve:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_execve . %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif 
      naive_uload(NULL, (const char *)a[1]); 
      a[4] = 0;
      break;

      case SYS_gettimeofday:
#ifdef SYSCALL_PRINTF
      printf("系统调用 syscall SYS_gettimeofday. %d %d %d %d",a[0],a[1],a[2],a[3]);
#endif 
      a[4] = sys_gettimeofday((void *)a[1]); 
      break;

    default: panic("没有实现的系统调用 syscall ID = %d", a[0]);
  }
#ifdef SYSCALL_PRINTF
      printf(" return %d\n",a[4]);
#endif 
   c->GPRx = a[4];
}
