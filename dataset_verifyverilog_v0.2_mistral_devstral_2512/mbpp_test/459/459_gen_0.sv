module remove_uppercase (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [127:0] str_out,
  output reg done
);

  reg [3:0] i; // Index for input string (0-15)
  reg [3:0] j; // Index for output string (0-15)
  reg [7:0] current_char;
  reg [3:0] state;

  // State definitions
  localparam IDLE = 4'b0001;
  localparam PROCESS = 4'b0010;
  localparam DONE = 4'b0100;

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      str_out <= 128'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            i <= 0;
            j <= 0;
            str_out <= 128'b0;
            done <= 1'b0;
          end
        end
        PROCESS: begin
          if (i == 15) begin
            state <= DONE;
          end else begin
            i <= i + 1;
          end
        end
        DONE: begin
          state <= IDLE;
          done <= 1'b0;
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Processing logic
  always @(posedge clk) begin
    if (state == PROCESS) begin
      current_char = str_in[(i+1)*8 - 1 : i*8];
      if (current_char >= 8'h41 && current_char <= 8'h5A) begin
        // Skip uppercase
      end else begin
        str_out[(j+1)*8 - 1 : j*8] = current_char;
        j <= j + 1;
      end
    end
  end

  // Done signal
  always @(posedge clk) begin
    if (state == DONE) begin
      done <= 1'b1;
    end
  end

endmodule