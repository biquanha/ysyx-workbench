module ysyx_22050019_alu(
 input [63:0] op_1,
 input [63:0] op_2,
 input [`LEN:0] alu_sel,
 
 output[63:0] result
);

wire  [31:0]op1_32 = op_1[31:0] ;
wire  [31:0]op2_32 = op_2[31:0] ;

wire  signed[31:0]sign_op1_32 = $signed(op_1[31:0]) ;
wire  signed[31:0]sign_op2_32 = $signed(op_2[31:0]) ;

wire  signed[63:0]sign_op1_64 = $signed(op_1[63:0]) ;
wire  signed[63:0]sign_op2_64 = $signed(op_2[63:0]) ;

// 复用加法器的控制信号处理
wire  op_suber    = {op_sltu|op_sub|op_slt|op_subw_32} ;

wire  op_sub      = alu_sel [2] ;
wire  op_subw_32  = alu_sel [3] ;
wire  op_slt      = alu_sel [4] ;
wire  op_sltu     = alu_sel [5] ;

// 把移位输入复用的控制信号(op2)
wire  op_shamt    = {op_slli_64|op_srli_64|op_srai_64} ;
wire  data_shamt  = op_shamt ? op_2[5] : 1'b0;

wire  op_slli_64  = alu_sel [10];
wire  op_srli_64  = alu_sel [14];
wire  op_srai_64  = alu_sel [18];

// 被移位的输入选择填充信号(op1)
wire [63:0]ushif_1= (op_srli_32|op_srl_32) ? {{32{1'b0}},op_1[31:0]} : op_1;

wire  op_srli_32  = alu_sel [15];
wire  op_srl_32   = alu_sel [16];

wire [63:0]sshif_1= (op_srai_32|op_sra_32) ? {{32{op_1[31]}},op_1[31:0]} : op_1;

wire  op_srai_32  = alu_sel [19];
wire  op_sra_32   = alu_sel [20];

// 除法的输入转换统一控制(为1是有无符号数，否者有符号)
wire [63:0]dat1_64= (op_remu_64|op_divu_64) ? op_1 : sign_op1_64;
wire [63:0]dat2_64= (op_remu_64|op_divu_64) ? op_2 : sign_op2_64;

wire  op_remu_64  = alu_sel [22];
wire  op_divu_64  = alu_sel [26];

/*    alu_sel 各个位的执行命令查看表
wire  op_add_64   = alu_sel [0] ;
wire  op_add_32   = alu_sel [1] ;

wire  op_and      = alu_sel [6] ;
wire  op_or       = alu_sel [7] ;
wire  op_xor      = alu_sel [8] ;

wire  op_sll_64   = alu_sel [9] ;
wire  op_slli_32  = alu_sel [11];
wire  op_sll_32   = alu_sel [12];

// 右移时32位需要考虑截取,有符号用符号位填充无符号用0填充
wire  op_srl_64   = alu_sel [13];

wire  op_sra_64   = alu_sel [17];

wire  op_rem_64   = alu_sel [21];
wire  op_rem_32   = alu_sel [24];

wire  op_div_64   = alu_sel [25];
wire  op_div_32   = alu_sel [28];

wire  op_mul_64   = alu_sel [29];
wire  op_mul_64   = alu_sel [30];
*/

//加减判断，add 结果有op_suber控制为加或者减
wire [63:0] op_2_in    = op_suber ?  (~op_2 + 64'b1) : op_2  ;//加减匹配位置
wire [63:0] add        = op_1 +op_2_in;

//对add的结果进行32位截断符号拓展
wire [63:0] SEXT_add_32= {{32{add[31]}},add[31:0]};

//有符号小于则置位
wire [63:0] slt        = ( ( ( op_1[63] == 1'b1 ) && ( op_2[63] == 1'b0 ) ) 
                        | ( (op_1[63] == op_2[63] ) && ( add[63] == 1'b1 ) ) ) ? 64'b1 : 64'b0 ;

//小于则置位，无符号
wire [63:0] sltu       = ( ( ( op_1[63] == 1'b0 ) && ( op_2[63] == 1'b1 ) ) 
                        | ( (op_1[63] == op_2[63] ) && ( add[63] == 1'b1 ) ) ) ? 64'b1 : 64'b0 ;

//对操作数1逻辑右移shanmt位（空位填0)
wire [63:0] srl        = ushif_1 >> {data_shamt,op_2[4:0]};

//对操作数1算术右移位shanmt位（rs1最高位填冲)
wire [63:0] sra        = $signed(sshif_1[63:0]) >>> {data_shamt,op_2[4:0]};// 有符号数64位的需要前面也带sign不然被转为无符号数 

//对操作数1进行逻辑左移（空位填0)
wire [63:0] sll        = op_1 << {data_shamt,op_2[4:0]};

//按位与
wire [63:0] and64      = op_1 & op_2 ;

//按位或
wire [63:0] or64       = op_1 | op_2 ;

//按位异或
wire [63:0] xor64      = op_1 ^ op_2 ;

//乘法器
wire [63:0] mul        = op_1 * op_2 ;
wire [63:0] mul_32     = {{32{mul[31]}},mul[31:0]};

//除法器
wire [63:0] div         = dat1_64 / dat2_64;
wire [31:0] div_32      = op1_32 / op2_32;
wire [31:0] div_32_s    = sign_op1_32 / sign_op2_32;

//取余数
wire [63:0] rem         = dat1_64 % dat2_64 ;
wire [31:0] rem_32      = op1_32 % op2_32 ;
wire [31:0] rem_32_s    = sign_op1_32 % sign_op2_32;

// alu的控制信号译码（用宏定义方便添加）
ysyx_22050019_mux #( .NR_KEY(`LEN+1'b1), .KEY_LEN(`LEN+1'b1), .DATA_LEN(64) ) mux_alu_result
(
  .key         (alu_sel), 
  .default_out (64'b0),
  .lut         ({
                 31'b1000000000000000000000000000000,mul_32,
                 31'b0100000000000000000000000000000,mul,
                 31'b0010000000000000000000000000000,{{32{div_32_s[31]}},div_32_s[31:0]},
                 31'b0001000000000000000000000000000,{{32{div_32[31]}},div_32[31:0]},
                 31'b0000100000000000000000000000000,div,
                 31'b0000010000000000000000000000000,$signed(div),
                 31'b0000001000000000000000000000000,{{32{rem_32_s[31]}},rem_32_s[31:0]},
                 31'b0000000100000000000000000000000,{{32{rem_32[31]}},rem_32[31:0]},
                 31'b0000000010000000000000000000000,rem,
                 31'b0000000001000000000000000000000,$signed(rem),
                 31'b0000000000100000000000000000000,{{32{sra[31]}},sra[31:0]},
                 31'b0000000000010000000000000000000,{{32{sra[31]}},sra[31:0]},
                 31'b0000000000001000000000000000000,sra,
                 31'b0000000000000100000000000000000,sra,
                 31'b0000000000000010000000000000000,{{32{srl[31]}},srl[31:0]},
                 31'b0000000000000001000000000000000,{{32{srl[31]}},srl[31:0]},
                 31'b0000000000000000100000000000000,srl,
                 31'b0000000000000000010000000000000,srl,
                 31'b0000000000000000001000000000000,{{32{sll[31]}},sll[31:0]},
                 31'b0000000000000000000100000000000,{{32{sll[31]}},sll[31:0]},
                 31'b0000000000000000000010000000000,sll,
                 31'b0000000000000000000001000000000,sll,
                 31'b0000000000000000000000100000000,xor64,
                 31'b0000000000000000000000010000000,or64,
                 31'b0000000000000000000000001000000,and64,
                 31'b0000000000000000000000000100000,sltu,
                 31'b0000000000000000000000000010000,slt,
                 31'b0000000000000000000000000001000,SEXT_add_32,
                 31'b0000000000000000000000000000100,add,
                 31'b0000000000000000000000000000010,SEXT_add_32,
                 31'b0000000000000000000000000000001,add
                 }),           
  .out         (result)  
);
endmodule
