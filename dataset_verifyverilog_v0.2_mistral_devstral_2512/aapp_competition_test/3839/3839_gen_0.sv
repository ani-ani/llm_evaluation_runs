module knight_generator (
  input clk,
  input rst_n,
  input start,
  input [9:0] n,
  output reg [31:0] x,
  output reg [31:0] y,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    GENERATE,
    DONE
  } state_t;

  state_t state;
  reg [9:0] knight_count;
  reg [9:0] block_index;
  reg [1:0] sub_pos;
  reg [9:0] delay_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      knight_count <= 0;
      block_index <= 0;
      sub_pos <= 0;
      delay_count <= 0;
      x <= 0;
      y <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            delay_count <= 0;
          end
        end
        INIT: begin
          if (delay_count == 3) begin
            state <= GENERATE;
            knight_count <= 0;
            block_index <= 0;
            sub_pos <= 0;
            delay_count <= 0;
          end else begin
            delay_count <= delay_count + 1;
          end
        end
        GENERATE: begin
          if (knight_count == n - 1) begin
            state <= DONE;
            valid <= 0;
            done <= 1;
          end else begin
            // Calculate coordinates
            block_index = knight_count / 3;
            sub_pos = knight_count % 3;
            case (sub_pos)
              0: begin
                x <= 2 * block_index;
                y <= 0;
              end
              1: begin
                x <= 2 * block_index + 1;
                y <= 0;
              end
              2: begin
                x <= 2 * block_index + 1;
                y <= 3;
              end
            endcase
            valid <= 1;
            knight_count <= knight_count + 1;
          end
        end
        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule