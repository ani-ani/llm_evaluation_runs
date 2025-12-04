module shell_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] data_in,
  output reg [7:0][7:0] data_out,
  output reg done
);

  localparam [2:0] IDLE       = 3'b000;
  localparam [2:0] LOAD       = 3'b001;
  localparam [2:0] GAP_CALC   = 3'b010;
  localparam [2:0] COMPARE    = 3'b011;
  localparam [2:0] SWAP       = 3'b100;
  localparam [2:0] UPDATE_GAP = 3'b101;
  localparam [2:0] DONE       = 3'b110;

  logic start_r, start_pulse;
  logic [7:0] mem [0:7];
  logic [7:0] gap;
  logic [2:0] gap_idx;
  logic [2:0] i, j, j_next, i_next;
  logic [5:0] count;
  logic [7:0] a_i, a_j;
  logic swap;
  logic mem_we;
  logic [7:0] mem_waddr;
  logic [7:0] mem_wdata;
  logic [7:0] mem_raddr1, mem_raddr2;
  logic [7:0] mem_rdata1, mem_rdata2;

  logic [2:0] state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r <= 1'b0;
    end else begin
      start_r <= start;
    end
  end
  assign start_pulse = start && !start_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  assign gaps[0] = 8'd4;
  assign gaps[1] = 8'd2;
  assign gaps[2] = 8'd1;

  always_comb begin
    next_state = state;
    case (state)
      IDLE:       next_state = start_pulse ? LOAD : IDLE;
      LOAD:       next_state = GAP_CALC;
      GAP_CALC:   next_state = (i + gap < 8) ? COMPARE : UPDATE_GAP;
      COMPARE:    next_state = SWAP;
      SWAP:       next_state = (i_next + gap_next < 8) ? COMPARE : UPDATE_GAP;
      UPDATE_GAP: next_state = (gap_idx_next < 2) ? GAP_CALC : DONE;
      DONE:       next_state = start_pulse ? LOAD : DONE;
      default:    next_state = IDLE;
    endcase
  end

  always_comb begin
    gap_idx_next = gap_idx;
    gap_next     = gap;
    i_next       = i;
    j_next       = j;
    case (state)
      IDLE: begin
        gap_idx_next = 3'd0;
        i_next       = 3'd0;
        j_next       = 3'd0;
      end
      LOAD: begin
        i_next = 3'd0;
      end
      GAP_CALC: begin
        gap_idx_next = (gap_idx < 2) ? (gap_idx + 1) : gap_idx;
        i_next       = 3'd0;
      end
      COMPARE: begin
        j_next = (j + gap >= 8) ? (3'd0) : (j + gap);
        i_next = i;
      end
      SWAP: begin
        if (i_next + gap_next < 8) begin
          j_next = (j_next + gap_next >= 8) ? 3'd0 : (j_next + gap_next);
        end else begin
          j_next = 3'd0;
        end
      end
      UPDATE_GAP: begin
        i_next = 3'd0;
      end
      DONE: begin
        i_next = 3'd0;
        j_next = 3'd0;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem <= '{default:'0};
    end else if (state == LOAD) begin
      mem <= data_in;
    end else if (mem_we) begin
      mem[mem_waddr] <= mem_wdata;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gap_idx <= 3'd0;
      gap     <= 8'd4;
      i       <= 3'd0;
      j       <= 3'd0;
      count   <= 6'd0;
    end else begin
      gap_idx <= gap_idx_next;
      gap     <= gaps[gap_idx_next];
      i       <= i_next;
      j       <= j_next;
      count   <= count + 1;
    end
  end

  assign mem_raddr1 = (state == COMPARE) ? i : (state == SWAP && swap) ? j : 8'd0;
  assign mem_raddr2 = (state == COMPARE) ? j : (state == SWAP && swap) ? i : 8'd0;

  always_ff @(posedge clk) begin
    a_i      <= mem[mem_raddr1];
    a_j      <= mem[mem_raddr2];
    mem_rdata1 <= mem[mem_raddr1];
    mem_rdata2 <= mem[mem_raddr2];
  end

  assign a_i      = mem[i];
  assign a_j      = mem[j];
  assign mem_rdata1 = mem[i];
  assign mem_rdata2 = mem[j];

  always_comb begin
    mem_we   = 1'b0;
    mem_waddr = 8'd0;
    mem_wdata = 8'd0;
    case (state)
      IDLE: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
      LOAD: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
      GAP_CALC: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
      COMPARE: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
      SWAP: begin
        if (swap) begin
          mem_we   = 1'b1;
          mem_waddr = j;
          mem_wdata = a_i;
        end else begin
          mem_we   = 1'b0;
          mem_waddr = 8'd0;
          mem_wdata = 8'd0;
        end
      end
      UPDATE_GAP: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
      DONE: begin
        mem_we   = 1'b0;
        mem_waddr = 8'd0;
        mem_wdata = 8'd0;
      end
    endcase
  end

  always_comb begin
    if (state == SWAP && mem_rdata1 > mem_rdata2) begin
      swap = 1'b1;
    end else begin
      swap = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      done <= (state == DONE);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= '{default:'0};
    end else begin
      data_out <= mem;
    end
  end

endmodule
