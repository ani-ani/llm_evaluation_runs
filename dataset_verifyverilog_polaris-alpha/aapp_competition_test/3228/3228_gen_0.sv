module gondola_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] t,
  input [1:0] g,
  input [4:0] skier_times [0:7],
  output reg [8:0] sum,
  output reg done
);

  // FSM states
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  reg [1:0] state, next_state;

  // Internal registers
  reg [4:0] sorted_times [0:7];
  reg [2:0] skier_idx;           // up to 8 skiers
  reg [1:0] g_eff;               // effective gondola count (1-3)
  reg [4:0] t_eff;               // effective T (0-31 but constrained 0-16)
  reg [8:0] twoT;                // 2*T, fits up to 32

  // Gondola next departure times
  // Use 9 bits to cover time up to about 255 comfortably
  reg [8:0] dep_time [0:2];

  // Combinational wires for processing current skier
  reg [8:0] selected_dep_time;
  reg [1:0] selected_gondola;
  reg [8:0] next_dep_time;
  reg [8:0] wait_time;

  integer i, j;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum   <= 9'd0;
      done  <= 1'b0;
      skier_idx <= 3'd0;
      g_eff <= 2'd0;
      t_eff <= 5'd0;
      twoT  <= 9'd0;
      for (i = 0; i < 8; i = i + 1) begin
        sorted_times[i] <= 5'd0;
      end
      for (i = 0; i < 3; i = i + 1) begin
        dep_time[i] <= 9'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch parameters
            if (g < 2'd1)
              g_eff <= 2'd1;
            else if (g > 2'd3)
              g_eff <= 2'd3;
            else
              g_eff <= g;

            t_eff <= t; // as per constraint

            twoT <= {4'd0, t} << 1; // 2*T

            // Copy skier_times into sorted_times
            for (i = 0; i < 8; i = i + 1) begin
              sorted_times[i] <= skier_times[i];
            end

            // Initialize dep_time to time -2T (0 minus 2T) using signed behavior emulated:
            // Represent -2T as (1's complement + 1) in 9 bits: (2^9 - 2T)
            // but simpler: just set to 0 and treat first departure specially via max.
            // However requirement: initialize to time -2T to indicate available.
            // We encode as (9'd0 - twoT).
            for (i = 0; i < 3; i = i + 1) begin
              dep_time[i] <= (9'd0 - twoT);
            end

            sum <= 9'd0;
            skier_idx <= 3'd0;
          end
        end

        PROCESSING: begin
          // Bubble sort combinationally and register result each cycle
          // (Inputs are already sorted or arbitrary, spec says implement bubble sort.)
          reg [4:0] temp_arr [0:7];
          reg [4:0] tmp;
          for (i = 0; i < 8; i = i + 1) begin
            temp_arr[i] = sorted_times[i];
          end
          for (i = 0; i < 7; i = i + 1) begin
            for (j = 0; j < 7 - i; j = j + 1) begin
              if (temp_arr[j] > temp_arr[j+1]) begin
                tmp = temp_arr[j];
                temp_arr[j] = temp_arr[j+1];
                temp_arr[j+1] = tmp;
              end
            end
          end
          for (i = 0; i < 8; i = i + 1) begin
            sorted_times[i] <= temp_arr[i];
          end

          // Process one skier per cycle (after sorting stabilized, still valid)
          if (skier_idx < n) begin
            // Update sum and departure time for selected gondola
            sum <= sum + wait_time;
            dep_time[selected_gondola] <= next_dep_time;
            skier_idx <= skier_idx + 3'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        if (skier_idx >= n)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Combinational allocation logic for current skier
  always @(*) begin
    // Default values
    selected_dep_time = dep_time[0];
    selected_gondola  = 2'd0;

    // Select gondola with earliest next departure among available g_eff
    if (g_eff > 2'd1) begin
      if (dep_time[1] < selected_dep_time) begin
        selected_dep_time = dep_time[1];
        selected_gondola  = 2'd1;
      end
    end
    if (g_eff > 2'd2) begin
      if (dep_time[2] < selected_dep_time) begin
        selected_dep_time = dep_time[2];
        selected_gondola  = 2'd2;
      end
    end

    // Current skier arrival time
    // If skier_idx >= n, these are don't-cares but computation is safe
    // arrival time in 0..31
    // Extend to 9 bits
    reg [8:0] arrival;
    arrival = {4'd0, sorted_times[skier_idx]};

    // Compute earliest possible departure for chosen gondola
    // If selected_dep_time < arrival, gondola can depart at arrival
    // else depart at selected_dep_time + 2T
    if (selected_dep_time < arrival) begin
      next_dep_time = arrival;
      wait_time = 9'd0; // departure equals arrival
    end else begin
      next_dep_time = selected_dep_time + twoT;
      if (next_dep_time > arrival)
        wait_time = next_dep_time - arrival;
      else
        wait_time = 9'd0;
    end
  end

endmodule