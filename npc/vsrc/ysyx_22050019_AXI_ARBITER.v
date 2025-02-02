module ysyx_22050133_axi_arbiter # (
    parameter AXI_DATA_WIDTH    = 64,
    parameter AXI_ADDR_WIDTH    = 32,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8
)(//IF&MEM输入信号
    input                               clk,
    input                               rst,

    // IFU_MEM
    output                              s1_axi_aw_ready_o,       
    input                               s1_axi_aw_valid_i,
    input [AXI_ADDR_WIDTH-1:0]          s1_axi_aw_addr_i,

    output                              s1_axi_w_ready_o,        
    input                               s1_axi_w_valid_i,
    input [AXI_DATA_WIDTH-1:0]          s1_axi_w_data_i,
    input [AXI_DATA_WIDTH/8-1:0]        s1_axi_w_strb_i,
    
    input                               s1_axi_b_ready_i,      
    output                              s1_axi_b_valid_o,
    output      [1:0]                   s1_axi_b_resp_o,          

    output                              s1_axi_ar_ready_o,       
    input                               s1_axi_ar_valid_i,
    input [AXI_ADDR_WIDTH-1:0]          s1_axi_ar_addr_i,
    input                               s1_axi_ar_len_i,
    
    input                               s1_axi_r_ready_i,            
    output                              s1_axi_r_valid_o,        
    output      [1:0]                   s1_axi_r_resp_o,
    output      [AXI_DATA_WIDTH-1:0]    s1_axi_r_data_o,

    //LSU_MEM
    output                              s2_axi_aw_ready_o,       
    input                               s2_axi_aw_valid_i,
    input [AXI_ADDR_WIDTH-1:0]          s2_axi_aw_addr_i,
    input                               s2_axi_rw_len_i,

    output                              s2_axi_w_ready_o,        
    input                               s2_axi_w_valid_i,
    input [AXI_DATA_WIDTH-1:0]          s2_axi_w_data_i,
    input [AXI_DATA_WIDTH/8-1:0]        s2_axi_w_strb_i,
    
    input                               s2_axi_b_ready_i,      
    output                              s2_axi_b_valid_o,
    output      [1:0]                   s2_axi_b_resp_o,          

    output                              s2_axi_ar_ready_o,       
    input                               s2_axi_ar_valid_i,
    input [AXI_ADDR_WIDTH-1:0]          s2_axi_ar_addr_i,
    
    input                               s2_axi_r_ready_i,            
    output                              s2_axi_r_valid_o,        
    output      [1:0]                   s2_axi_r_resp_o,
    output      [AXI_DATA_WIDTH-1:0]    s2_axi_r_data_o, 

    // arbiter<>sram
    input                               axi_aw_ready_i,             
    output                              axi_aw_valid_o,
    output     [AXI_ADDR_WIDTH-1:0]     axi_aw_addr_o,
    output                              axi_aw_len_o,

    input                               axi_w_ready_i,              
    output                              axi_w_valid_o,
    output     [AXI_DATA_WIDTH-1:0]     axi_w_data_o,
    output     [AXI_DATA_WIDTH/8-1:0]   axi_w_strb_o,
    
    output                              axi_b_ready_o,          
    input                               axi_b_valid_i,
    input  [1:0]                        axi_b_resp_i,               

    input                               axi_ar_ready_i,             
    output                              axi_ar_valid_o,
    output     [AXI_ADDR_WIDTH-1:0]     axi_ar_addr_o,
    output                              axi_ar_len_o,
    
    output                              axi_r_ready_o,          
    input                               axi_r_valid_i,             
    input  [1:0]                        axi_r_resp_i,
    input  [AXI_DATA_WIDTH-1:0]         axi_r_data_i  
);

reg r_channel;
wire w_channel = 1;

assign s2_axi_aw_ready_o= w_channel ? axi_aw_ready_i    : 0;
assign s1_axi_aw_ready_o= ~w_channel? axi_aw_ready_i    : 0;
assign axi_aw_valid_o   = w_channel ? s2_axi_aw_valid_i : s1_axi_aw_valid_i;
assign axi_aw_addr_o    = w_channel ? s2_axi_aw_addr_i  : s1_axi_aw_addr_i;
assign axi_aw_len_o     = w_channel ? s2_axi_rw_len_i   : 0;

assign s2_axi_w_ready_o = w_channel ? axi_w_ready_i     : 0;
assign s1_axi_w_ready_o = ~w_channel? axi_w_ready_i     : 0; 
assign axi_w_valid_o    = w_channel ? s2_axi_w_valid_i  : s1_axi_w_valid_i;
assign axi_w_data_o     = w_channel ? s2_axi_w_data_i   : s1_axi_w_data_i;
assign axi_w_strb_o     = w_channel ? s2_axi_w_strb_i   : s1_axi_w_strb_i;

assign axi_b_ready_o    = w_channel ? s2_axi_b_ready_i  : s1_axi_b_ready_i;    
assign s2_axi_b_valid_o = w_channel ? axi_b_valid_i     : 0;
assign s2_axi_b_resp_o  = w_channel ? axi_b_resp_i      : 0;
assign s1_axi_b_valid_o = ~w_channel? axi_b_valid_i     : 0;
assign s1_axi_b_resp_o  = ~w_channel? axi_b_resp_i      : 0;

assign s2_axi_ar_ready_o= r_channel ? axi_ar_ready_i    : 0;
assign s1_axi_ar_ready_o= ~r_channel? axi_ar_ready_i    : 0;
assign axi_ar_valid_o   = r_channel ? s2_axi_ar_valid_i : s1_axi_ar_valid_i;
assign axi_ar_addr_o    = r_channel ? s2_axi_ar_addr_i  : s1_axi_ar_addr_i;
assign axi_ar_len_o     = r_channel ? s2_axi_rw_len_i   : s1_axi_ar_len_i;

assign axi_r_ready_o    = r_channel ? s2_axi_r_ready_i  : s1_axi_r_ready_i;    
assign s2_axi_r_valid_o = r_channel ? axi_r_valid_i     : 0;
assign s2_axi_r_resp_o  = r_channel ? axi_r_resp_i      : 0;
assign s2_axi_r_data_o  = r_channel ? axi_r_data_i      : 0;
assign s1_axi_r_valid_o = ~r_channel? axi_r_valid_i     : 0;
assign s1_axi_r_resp_o  = ~r_channel? axi_r_resp_i      : 0;
assign s1_axi_r_data_o  = ~r_channel? axi_r_data_i      : 0;

parameter R_IDLE = 1;
parameter R_S1   = 2;
parameter R_S2   = 3;

reg[2:0] rstate;
reg[2:0] next_rstate;
 
 //import "DPI-C" function void arbiter_wait();
//========================================
// 读状态机
always@(posedge clk)begin
  if(rst)rstate<=R_IDLE;
  else rstate<=next_rstate;
end

always@(*) begin
  if(rst)next_rstate=R_IDLE;
  else case(rstate)
    R_IDLE:if(s1_axi_ar_valid_i)next_rstate=R_S1;
		  else if(s2_axi_ar_valid_i)next_rstate=R_S2;
      else next_rstate=R_IDLE;
		R_S1:if(s1_axi_r_ready_i&axi_r_valid_i&(s1_axi_ar_len_i == 0))next_rstate= s2_axi_ar_valid_i ? R_S2 :R_IDLE;
	    else next_rstate=R_S1;
		R_S2:if(s2_axi_r_ready_i&axi_r_valid_i&(s2_axi_rw_len_i == 0))next_rstate=R_IDLE;
    else next_rstate=R_S2;
    default:next_rstate=R_IDLE;
  endcase
end
always@(posedge clk)begin
  if(rst)begin
        r_channel<=0;
  end
  else begin
    case(rstate)
      R_IDLE:
      if (next_rstate==R_S1)begin
      end
      else if(next_rstate==R_S2)begin
//        arbiter_wait();//多跑3个周期平衡
        r_channel<= 1;
      end
      else begin
        r_channel<=0;
      end

      R_S1:
      if(next_rstate==R_IDLE)begin
        r_channel<=0;
      end
      else if(next_rstate==R_S2)begin
        r_channel<= 1;
      end

      R_S2:
     if(next_rstate==R_IDLE)begin
        r_channel<=0;
      end

      default:begin
      end
    endcase
  end
end
endmodule
