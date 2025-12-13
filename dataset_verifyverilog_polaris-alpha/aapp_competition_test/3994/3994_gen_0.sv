module max_lights_on(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] init_state,
  input [23:0] a_vals,
  input [23:0] b_vals,
  output reg [3:0] max_on,
  output reg done
);

  // Internal registers
  reg [4:0] t_cnt;              // time counter: 0..25
  reg [7:0] lights_state;       // current light states
  reg [2:0] a_arr [7:0];        // a_i values
  reg [2:0] b_arr [7:0];        // b_i values

  reg [3:0] curr_on;            // current ON count
  reg [3:0] max_on_next;
  reg [7:0] toggle_mask;        // which lights toggle at current time

  reg running;                  // indicates computation in progress

  integer i;

  // Unpack a_vals and b_vals into arrays for easier indexing
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      a_arr[i] = a_vals[i*3 +: 3];
      b_arr[i] = b_vals[i*3 +: 3];
    end
  end

  // Main sequential process
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      t_cnt        <= 5'd0;
      lights_state <= 8'd0;
      max_on       <= 4'd0;
      done         <= 1'b0;
      running      <= 1'b0;
    end else begin
      if (start && !running) begin
        // Initialize on start pulse
        running      <= 1'b1;
        done         <= 1'b0;
        t_cnt        <= 5'd0;
        lights_state <= init_state;
        // Compute initial ON count for first time step (t=0)
        curr_on      <= (init_state[0] + init_state[1] + init_state[2] + init_state[3] +
                         init_state[4] + init_state[5] + init_state[6] + init_state[7]);
        max_on       <= (init_state[0] + init_state[1] + init_state[2] + init_state[3] +
                         init_state[4] + init_state[5] + init_state[6] + init_state[7]);
      end else if (running) begin
        // For t_cnt from 0 to 24 inclusive, perform updates; at end assert done
        // Compute toggle mask based on current time t_cnt
        toggle_mask = 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
          if (i < n) begin
            if ((t_cnt >= b_arr[i]) && (a_arr[i] != 3'd0)) begin
              if (((t_cnt - b_arr[i]) % a_arr[i]) == 0)
                toggle_mask[i] = 1'b1;
              else
                toggle_mask[i] = 1'b0;
            end else begin
              toggle_mask[i] = 1'b0;
            end
          end else begin
            toggle_mask[i] = 1'b0;
          end
        end

        // Update lights_state by toggling where needed
        lights_state <= lights_state ^ toggle_mask;

        // Count current ON lights after toggle
        curr_on <= ((lights_state ^ toggle_mask)[0] + (lights_state ^ toggle_mask)[1] +
                    (lights_state ^ toggle_mask)[2] + (lights_state ^ toggle_mask)[3] +
                    (lights_state ^ toggle_mask)[4] + (lights_state ^ toggle_mask)[5] +
                    (lights_state ^ toggle_mask)[6] + (lights_state ^ toggle_mask)[7]);

        // Update max_on
        if (((lights_state ^ toggle_mask)[0] + (lights_state ^ toggle_mask)[1] +
             (lights_state ^ toggle_mask)[2] + (lights_state ^ toggle_mask)[3] +
             (lights_state ^ toggle_mask)[4] + (lights_state ^ toggle_mask)[5] +
             (lights_state ^ toggle_mask)[6] + (lights_state ^ toggle_mask)[7]) > max_on)
          max_on <= ((lights_state ^ toggle_mask)[0] + (lights_state ^ toggle_mask)[1] +
                     (lights_state ^ toggle_mask)[2] + (lights_state ^ toggle_mask)[3] +
                     (lights_state ^ toggle_mask)[4] + (lights_state ^ toggle_mask)[5] +
                     (lights_state ^ toggle_mask)[6] + (lights_state ^ toggle_mask)[7]);

        // Increment time counter and control done signal
        if (t_cnt == 5'd24) begin
          // After processing t=24, stop and assert done
          running <= 1'b0;
          done    <= 1'b1;
          t_cnt   <= t_cnt; // hold
        end else begin
          t_cnt <= t_cnt + 5'd1;
          done  <= 1'b0;
        end
      end else begin
        // Idle: hold outputs
        done <= done;
      end
    end
  end

endmodule