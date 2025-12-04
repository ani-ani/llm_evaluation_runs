module string_modifier(
  input clk,
  input rst_n,
  input start,
  input [7:0] s1 [0:15],
  input [7:0] s2 [0:15],
  input [3:0] length,
  output reg [8:0] moves,
  output reg done
);

  typedef enum logic [1:0] { IDLE = 0, PROCESSING = 1, DONE = 2 } state_t;
  state_t state;
  reg [3:0] counter;
  reg prev_dir;
  
  logic signed [8:0] diff_raw;
  logic signed [8:0] mod_adjust;
  logic [4:0] diff_mod;
  logic [4:0] minimal_move;
  logic current_dir;

  always_comb begin : calc_diff
    diff_raw = $signed(s2[counter]) - $signed(s1[counter]);
    mod_adjust = diff_raw % 26;
    diff_mod = (mod_adjust >= 0) ? mod_adjust[4:0] : (mod_adjust + 26)[4:0];
    minimal_move = (diff_mod <= 13) ? diff_mod : (26 - diff_mod);
    current_dir = (diff_mod <= 13) ? 1'b1 : 1'b0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 1'b1;
      moves <= 9'b0;
      counter <= 4'b0;
      prev_dir <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b1;
          if (start) begin
            state <= PROCESSING;
            done <= 1'b0;
            moves <= 9'b0;
            counter <= 4'b0;
            prev_dir <= 1'b0;
          end
        end

        PROCESSING: begin
          if (counter < length) begin
            if (counter == 4'b0) begin
              moves <= minimal_move;
              prev_dir <= current_dir;
            end else begin
              moves <= moves + minimal_move + (current_dir != prev_dir ? 9'd1 : 9'd0);
              prev_dir <= current_dir;
            end
            counter <= counter + 1;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
          counter <= 4'b0;
        end
      endcase
    end
  end

endmodule