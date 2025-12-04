module rook_attack_counter(
  input clk, 
  input rst_n, 
  input start_move, 
  input [1:0] incoming_r, 
  input [1:0] incoming_c, 
  input [7:0] incoming_power, 
  input [1:0] old_r, 
  input [1:0] old_c, 
  output reg [4:0] attacked_count, 
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    REMOVE_OLD,
    ADD_NEW,
    COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [1:0] rows[0:3];
  reg [1:0] cols[0:3];
  reg [7:0] powers[0:3];
  reg valids[0:3];
  reg [3:0] cycle_counter;
  reg [1:0] curr_row, curr_col;
  wire enable_remove = (state == REMOVE_OLD);
  wire enable_add = (state == ADD_NEW);
  wire computing = (state == COMPUTE);
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      for (i = 0; i < 4; i = i + 1) begin
        valids[i] <= 1'b0;
        rows[i] <= 2'b00;
        cols[i] <= 2'b00;
        powers[i] <= 8'b0;
      end
      attacked_count <= 5'b0;
      done <= 1'b0;
      cycle_counter <= 4'b0;
    end
    else begin
      done <= 1'b0;
      case(state)
        IDLE: begin
          cycle_counter <= 4'b0;
          attacked_count <= 5'b0;
          if (start_move) state <= REMOVE_OLD;
        end

        REMOVE_OLD: begin
          for (i = 0; i < 4; i = i + 1) begin
            if (valids[i] && rows[i] == old_r && cols[i] == old_c)
              valids[i] <= 1'b0;
          end
          state <= ADD_NEW;
        end

        ADD_NEW: begin
          for (i = 0; i < 4; i = i + 1) begin
            if (~valids[i]) begin
              valids[i] <= 1'b1;
              rows[i] <= incoming_r;
              cols[i] <= incoming_c;
              powers[i] <= incoming_power;
              break;
            end
          end
          state <= COMPUTE;
        end

        COMPUTE: begin
          cycle_counter <= cycle_counter + 1;
          if (cycle_counter == 4'd15)
            state <= DONE;
          
          // Attack calculation
          curr_row <= cycle_counter[3:2];
          curr_col <= cycle_counter[1:0];
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase

      // Accumulate attack count during compute
      if (computing) begin
        automatic logic [7:0] xor_result = 8'b0;
        for (int j = 0; j < 4; j = j + 1) begin
          if (valids[j] && 
              ( (rows[j] == curr_row) || (cols[j] == curr_col) ) && 
              !(rows[j] == curr_row && cols[j] == curr_col))
            xor_result = xor_result ^ powers[j];
        end
        attacked_count <= attacked_count + (xor_result != 8'b0);
      end
    end
  end

endmodule