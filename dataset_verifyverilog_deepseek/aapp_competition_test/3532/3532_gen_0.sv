module string_explosion_filter(
  input clk,
  input rst_n,
  input start,
  input [127:0] input_str,
  input [31:0] explosion,
  input [2:0] str_len,
  input [1:0] exp_len,
  output reg [127:0] result_str,
  output reg [3:0] out_len,
  output reg done
);

  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] LOAD = 3'd1;
  localparam [2:0] PROCESS = 3'd2;
  localparam [2:0] FINISH = 3'd3;
  reg [2:0] state;
  
  reg [127:0] working_buf;
  reg [3:0] current_len;
  wire [15:0] match_pos;
  wire any_match;
  wire [3:0] first_match;

  // Match detection logic
  reg [15:0] match_pos_reg;
  always_comb begin
    match_pos_reg = 16'd0;
    for (int i=0; i < 16; i++) begin
      if (i <= current_len - exp_len) begin
        match_pos_reg[i] = 1'b1;
        for (int j=0; j < exp_len; j++) begin
          if (working_buf[i*8 + j*8 +: 8] != explosion[j*8 +: 8]) begin
            match_pos_reg[i] = 1'b0;
          end
        end
      end else begin
        match_pos_reg[i] = 1'b0;
      end
    end
  end
  assign any_match = |match_pos_reg;

  // Priority encoder for leftmost match
  assign first_match =
    match_pos_reg[0] ? 4'd0 :
    match_pos_reg[1] ? 4'd1 :
    match_pos_reg[2] ? 4'd2 :
    match_pos_reg[3] ? 4'd3 :
    match_pos_reg[4] ? 4'd4 :
    match_pos_reg[5] ? 4'd5 :
    match_pos_reg[6] ? 4'd6 :
    match_pos_reg[7] ? 4'd7 :
    match_pos_reg[8] ? 4'd8 :
    match_pos_reg[9] ? 4'd9 :
    match_pos_reg[10] ? 4'd10 :
    match_pos_reg[11] ? 4'd11 :
    match_pos_reg[12] ? 4'd12 :
    match_pos_reg[13] ? 4'd13 :
    match_pos_reg[14] ? 4'd14 :
    match_pos_reg[15] ? 4'd15 : 4'd0;

  // Shifted buffer logic
  reg [127:0] shifted_buf;
  always_comb begin
    shifted_buf = 128'd0;
    if (any_match) begin
      for (int i=0; i < first_match; i++) begin
        shifted_buf[i*8 +: 8] = working_buf[i*8 +: 8];
      end
      for (int i=first_match; i < (current_len - exp_len); i++) begin
        shifted_buf[i*8 +: 8] = working_buf[(i + exp_len)*8 +: 8];
      end
    end
  end

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      working_buf <= 128'd0;
      current_len <= 4'd0;
      result_str <= 128'd0;
      out_len <= 4'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) state <= LOAD;
        end
        
        LOAD: begin
          working_buf <= input_str;
          current_len <= {1'b0, str_len};
          state <= PROCESS;
        end
        
        PROCESS: begin
          if (any_match) begin
            working_buf <= shifted_buf;
            current_len <= current_len - exp_len;
          end else begin
            state <= FINISH;
          end
        end
        
        FINISH: begin
          if (current_len == 4'd0) begin
            result_str <= {40'h4652554C41, 88'd0}; // FRULA\0
            out_len <= 4'd5;
          end else begin
            result_str <= working_buf;
            out_len <= current_len;
          end
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule