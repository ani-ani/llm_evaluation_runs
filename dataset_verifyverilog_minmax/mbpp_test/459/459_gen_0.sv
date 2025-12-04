module remove_uppercase (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [127:0] str_out,
  output reg [4:0] out_length,
  output reg done
);

  // Control signals
  wire [7:0] char;
  wire valid;
  reg [4:0] idx;
  reg [3:0] state;

  // Character selector and validity check
  assign char   = str_in[127:120];
  assign valid  = (char >= 8'h61 && char <= 8'h7A) || // a-z
                  ~((char >= 8'h41 && char <= 8'h5A)); // not A-Z

  // FSM: idle -> run (16 cycles) -> done (1 cycle) -> idle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= 4'd0;
      str_out   <= 128'b0;
      out_length <= 5'd0;
      idx       <= 5'd0;
      done      <= 1'b0;
    end else begin
      case (state)
        4'd0: begin
          str_out   <= 128'b0;
          out_length <= 5'd0;
          idx       <= 5'd0;
          done      <= 1'b0;
          if (start) begin
            state <= 4'd1; // enter run state
          end else begin
            state <= 4'd0; // stay idle
          end
        end

        4'd1: begin
          // One character per cycle, pack left-aligned into str_out
          if (valid) begin
            str_out <= {str_out[119:0], char};
            out_length <= out_length + 1'b1;
          end else begin
            str_out <= str_out; // shift only via next idx (no change to content)
            out_length <= out_length;
          end
          idx <= idx + 1'b1;
          if (idx == 5'd15) begin
            state <= 4'd2; // last character processed; next cycle set done
          end else begin
            state <= 4'd1; // continue
          end
        end

        4'd2: begin
          // Output valid on this cycle; maintain until next start
          done <= 1'b1;
          state <= 4'd0; // return to idle; out_length/str_out already valid
        end

        default: state <= 4'd0;
      endcase
    end
  end

endmodule
