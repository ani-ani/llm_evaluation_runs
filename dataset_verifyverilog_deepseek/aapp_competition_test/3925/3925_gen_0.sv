module max_zebra_length(
  input clk,
  input rst_n,
  input start,
  input [15:0] data_in,
  input [3:0] data_len,
  output reg [4:0] max_streak,
  output reg done
);
  localparam IDLE = 2'd0;
  localparam PROCESS_FORWARD = 2'd1;
  localparam PROCESS_BACKWARD = 2'd2;
  localparam COMPLETE = 2'd3;
  
  reg [1:0] state;
  reg [15:0] data_reg;
  reg [3:0] len_reg;
  reg [4:0] current_streak;
  reg [4:0] max_streak_forward;
  reg [4:0] initial_streak;
  reg initial_active;
  reg [3:0] forward_index;
  reg [3:0] backward_index;
  reg [4:0] ending_streak;
  reg first_char, last_char;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      max_streak <= 0;
      current_streak <= 0;
      max_streak_forward <= 0;
      initial_streak <= 0;
      initial_active <= 0;
      ending_streak <= 0;
      forward_index <= 0;
      backward_index <= 0;
      data_reg <= 0;
      len_reg <= 0;
      first_char <= 0;
      last_char <= 0;
    end else begin
      done <= 0;
      
      case (state)
        IDLE: begin
          if (start) begin
            data_reg <= data_in;
            len_reg <= data_len;
            first_char <= data_in[0];
            last_char <= data_in[data_len-1];
            current_streak <= 5'd1;
            max_streak_forward <= 5'd1;
            initial_streak <= 5'd1;
            initial_active <= 1'b1;
            forward_index <= 4'd1;
            state <= PROCESS_FORWARD;
          end
        end
        
        PROCESS_FORWARD: begin
          if (forward_index < len_reg) begin
            if (data_reg[forward_index] != data_reg[forward_index-1]) begin
              current_streak <= current_streak + 1;
              if (initial_active) initial_streak <= initial_streak + 1;
            end else begin
              current_streak <= 5'd1;
              initial_active <= 1'b0;
            end
            
            if (current_streak + 1 > max_streak_forward) begin
              max_streak_forward <= current_streak + 1;
            end
            
            forward_index <= forward_index + 1;
          end else begin
            if (first_char != last_char) begin
              backward_index <= len_reg - 2;
              ending_streak <= 5'd1;
              state <= PROCESS_BACKWARD;
            end else begin
              state <= COMPLETE;
            end
          end
        end
        
        PROCESS_BACKWARD: begin
          if (backward_index < 4'd15) begin // Prevent underflow
            if (data_reg[backward_index] != data_reg[backward_index + 1]) begin
              ending_streak <= ending_streak + 1;
              backward_index <= backward_index - 1;
            end else begin
              state <= COMPLETE;
            end
          end else state <= COMPLETE;
        end
        
        COMPLETE: begin
          if (first_char != last_char) begin
            automatic logic [4:0] candidate = initial_streak + ending_streak;
            if (candidate > len_reg) candidate = len_reg;
            max_streak <= (candidate > max_streak_forward) ? candidate : max_streak_forward;
          end else max_streak <= max_streak_forward;
          
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
