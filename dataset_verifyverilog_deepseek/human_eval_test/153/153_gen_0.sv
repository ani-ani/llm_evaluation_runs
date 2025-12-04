module strongest_extension (
  input clk,
  input rst_n,
  input start,
  input [127:0] class_name,
  input [1023:0] extensions,
  input [2:0] num_extensions,
  output reg [2:0] strongest_idx,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESS, EVAL} state_t;
  state_t state, next_state;

  reg [2:0] ext_idx;
  reg [3:0] char_idx;
  reg signed [5:0] current_strength;
  reg signed [5:0] max_strength;
  reg [2:0] strongest_idx_reg;
  reg [127:0] current_extension;

  wire [7:0] char_byte = current_extension[char_idx*8 +: 8];
  wire is_capital = (char_byte >= 8'h41) && (char_byte <= 8'h5A);
  wire is_lower = (char_byte >= 8'h61) && (char_byte <= 8'h7A);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      strongest_idx <= 3'b0;
      ext_idx <= 3'b0;
      char_idx <= 4'b0;
      current_strength <= 6'sd0;
      max_strength <= -6'sd32;
      strongest_idx_reg <= 3'b0;
      current_extension <= 128'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= PROCESS;
            ext_idx <= 3'b0;
            char_idx <= 4'b0;
            current_strength <= 6'sd0;
            max_strength <= -6'sd32;
            strongest_idx_reg <= 3'b0;
            current_extension <= extensions[0*128 +:128];
          end
        end

        PROCESS: begin
          if (is_capital) current_strength <= current_strength + 6'sd1;
          else if (is_lower) current_strength <= current_strength - 6'sd1;

          if (char_idx == 4'd15) begin
            state <= EVAL;
          end else begin
            char_idx <= char_idx + 4'd1;
          end
        end

        EVAL: begin
          if (current_strength > max_strength) begin
            max_strength <= current_strength;
            strongest_idx_reg <= ext_idx;
          end

          if (ext_idx == (num_extensions - 3'd1)) begin
            done <= 1'b1;
            strongest_idx <= strongest_idx_reg;
            state <= IDLE;
          end else begin
            ext_idx <= ext_idx + 3'd1;
            char_idx <= 4'd0;
            current_strength <= 6'sd0;
            current_extension <= extensions[(ext_idx + 1)*128 +:128];
            state <= PROCESS;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule