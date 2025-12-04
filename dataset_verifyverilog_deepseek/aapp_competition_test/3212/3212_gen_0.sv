module snake_path_finder(
    input clk,
    input rst_n,
    input start,
    input [23:0] snake_data,
    input snake_valid,
    input [7:0] snake_count,
    output reg [15:0] entry_exit,
    output reg valid_out,
    output reg bitten
);

  // State machine states
  enum logic [1:0] {
    IDLE,
    LOAD_SNAKES,
    PROCESS,
    DONE
  } state, next_state;

  // Snake storage structure
  typedef struct packed {
    logic [7:0] x;
    logic [7:0] y;
    logic [15:0] d_sq;
  } snake_t;
  snake_t [15:0] snake_mem;

  // Control registers
  logic [3:0] load_cnt;
  logic [7:0] sample_x;
  logic [7:0] y_entry_val;
  logic [9:0] cycle_counter;
  logic current_entry_safe;
  logic [7:0] highest_y_entry;
  logic has_safe_path;
  logic signed [8:0] dx, dy;
  logic [16:0] dx_sq, dy_sq;
  logic [17:0] distance_sq;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid_out <= 1'b0;
      bitten <= 1'b0;
      entry_exit <= 16'd0;
      load_cnt <= 4'd0;
      snake_mem <= '{default:0};
      cycle_counter <= 10'd0;
      current_entry_safe <= 1'b1;
      highest_y_entry <= 8'd0;
      has_safe_path <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_SNAKES;
            load_cnt <= 4'd0;
          }
          valid_out <= 1'b0;
          bitten <= 1'b0;
        end

        LOAD_SNAKES: begin
          if (snake_valid && (load_cnt < snake_count[3:0])) begin
            snake_mem[load_cnt].x <= snake_data[7:0];
            snake_mem[load_cnt].y <= snake_data[15:8];
            snake_mem[load_cnt].d_sq <= snake_data[23:16] * snake_data[23:16];
            load_cnt <= load_cnt + 4'd1;
          end
          if (load_cnt == snake_count[3:0]) begin
            state <= PROCESS;
            highest_y_entry <= 8'd0;
            has_safe_path <= 1'b0;
            cycle_counter <= 10'd0;
          end
        end

        PROCESS: begin
          if (cycle_counter < 10'd1024) begin
            if (cycle_counter[5:0] == 6'b000000) begin
              current_entry_safe <= 1'b1;
            end

            // Calculate sample x coordinate
            case (cycle_counter[1:0])
              2'd0: sample_x <= 8'd0;
              2'd1: sample_x <= 8'd85;
              2'd2: sample_x <= 8'd170;
              2'd3: sample_x <= 8'd255;
            endcase

            // Calculate current y entry
            y_entry_val <= 8'd255 - (cycle_counter[9:6] * 8'd16);

            // Distance calculation
            dx = $signed(sample_x) - $signed(snake_mem[cycle_counter[5:2]].x);
            dy = $signed(y_entry_val) - $signed(snake_mem[cycle_counter[5:2]].y);
            dx_sq = dx * dx;
            dy_sq = dy * dy;
            distance_sq = dx_sq + dy_sq;

            if ((cycle_counter[5:2] < snake_count[3:0]) &&
                (distance_sq < snake_mem[cycle_counter[5:2]].d_sq)) begin
              current_entry_safe <= 1'b0;
            end

            // End of entry processing block
            if (cycle_counter[5:0] == 6'b111111) begin
              if (current_entry_safe) begin
                if (y_entry_val > highest_y_entry) begin
                  highest_y_entry <= y_entry_val;
                  has_safe_path <= 1'b1;
                end
              end
            end

            cycle_counter <= cycle_counter + 10'd1;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          valid_out <= 1'b1;
          bitten <= ~has_safe_path;
          entry_exit <= {highest_y_entry, highest_y_entry};
          has_safe_path <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule