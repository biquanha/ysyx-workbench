//第一级流水，时序逻辑

module ysyx_22050019_IFU#(
  RESET_VAL = 64'h80000000
)
(
    input                 clk               ,
    input                 rst_n             ,

    //pc 的跳转控制信号
    input                 inst_j            ,
    input   [63:0]        snpc              ,  
    
    input  [63:0]         inst_i            ,
    input  [1:0]          m_axi_r_resp_i    ,
    output                m_axi_rready      ,
    input                 m_axi_rvalid      ,

    input                 m_axi_arready     ,
    output                m_axi_arvalid     ,
    output                inst_commite      ,

    //五级流水的适配控制信号的输入和输出
    input                 pc_stall_i        ,
    
    // 送出指令和对于pc的接口（打了一拍）
    output                ifu_ok_o          ,
    output  [63:0]        inst_addr_o       , //到指令寄存器中取指令的地址
    output  [31:0]        inst_o
);

//=========================  
// AXI的接口逻辑      
  // 状态准备
  localparam IDLE = 1'd0;
  localparam WAIT_READY = 1'd1;

  reg  state_reg;
  reg  next_state;
  
  reg [1:0] rresp;
  // 状态转移
  always @(posedge clk) begin
    if (rst_n) begin
      state_reg <= IDLE;
    end else begin
      state_reg <= next_state;
    end
  end
 always@(*) begin
  if(rst_n) next_state = IDLE;
  else case(state_reg)
    IDLE :if(m_axi_arready) next_state = WAIT_READY;
      else next_state = IDLE;

    WAIT_READY : if(pc_wen)next_state = IDLE;
    else next_state = WAIT_READY;

    default : next_state = IDLE;
  endcase
end
reg rready;
reg rrvalid;
  // 读的状态机
always@(posedge clk)begin
  if(rst_n)begin
        rrvalid         <= 1'b0;
        rready          <= 1'b0;
        rresp           <= 2'b0;
  end
  else begin
    case(state_reg)
      IDLE:
      if(next_state==WAIT_READY) begin
        rrvalid         <= 1'b0;
        rready          <= 1;
      end
      else begin
        rresp           <= 2'b0;
        rrvalid         <= 1'b1;
        rready          <= 1'b0;
      end

      WAIT_READY:if(next_state==IDLE)begin
        rrvalid         <= 1'b1;
        rready          <= 1'b0;
        rresp           <= m_axi_r_resp_i;
      end
      else begin
        rrvalid         <= 1'b0;
        rready          <= 1;
      end
      default:begin
      end
    endcase
  end
end
assign m_axi_rready = (~pc_stall_i) ? rready : 0;
assign m_axi_arvalid = rrvalid;
//=========================
//=========================

  wire pc_wen = rready && m_axi_rvalid && (~pc_stall_i); //暂停指示信号，目前用这个代替，后面需要参考优秀设计
  reg [63:0]     inst_addr; 
// pc 计数器
always @ (posedge clk) begin
    // 复位
    if (rst_n) begin
        inst_addr <= RESET_VAL;
    // 跳转
    end else if (inst_j&(~pc_stall_i)) begin
        inst_addr <= snpc;
    // 暂停
    end else if (~pc_wen) begin
        inst_addr <= inst_addr;
    // 地址加4
    end else begin
        inst_addr <= inst_addr + 64'h4;
    end
end
//=========================
//IFU第一级取指令流水操作
assign inst_addr_o = inst_j&(~pc_stall_i) ? snpc : inst_addr;
assign inst_o      = inst_addr [2] ? inst_i[63:32] : inst_i[31:0];
assign inst_commite= pc_wen & ~inst_j;
assign ifu_ok_o    = pc_wen;
endmodule
