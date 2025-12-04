module service_verifier(
  input clk,
  input rst_n,
  input start,
  input [4:0][15:0] years_months,
  input [4:0][16:0] odos,
  output reg [1:0] status
);

  // Internal registers
  reg [1:0] state;
  reg [2:0] i;
  reg [3:0] cycle_cnt;
  reg [11:0] prev_months;
  reg [16:0] prev_odo;
  reg [11:0] months_curr;
  reg [31:0] delta_months;
  reg [31:0] delta_odo;
  reg [31:0] min_odo;
  reg [31:0] max_odo;

  // State machine parameters
  localparam IDLE = 2'b00;
  localparam COMPARE = 2'b01;
  localparam DONE = 2'b10;

  // Main sequential logic
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      status <= 2'b00;
      i <= 3'b0;
      cycle_cnt <= 4'b0;
      prev_months <= 12'b0;
      prev_odo <= 17'b0;
    end else begin
      // Default: keep current values
      state <= state;
      status <= status;
      i <= i;
      cycle_cnt <= cycle_cnt;
      prev_months <= prev_months;
      prev_odo <= prev_odo;

      // Compute months for the current entry
      months_curr = (years_months[i][15:8] * 12) + (years_months[i][7:0] - 1);

      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPARE;
            i <= 3'b0;
            cycle_cnt <= 4'b0;
            status <= 2'b00;
          end
        end

        COMPARE: begin
          // Increment cycle counter
          cycle_cnt <= cycle_cnt + 1;

          if (i < 3'b101) begin // i < 5
            if (i == 3'b0) begin
              // Initialize previous values
              prev_months <= months_curr;
              prev_odo <= odos[i];
            end else begin
              // Compute delta months and odometer
              delta_months = months_curr - prev_months;
              if (odos[i] >= prev_odo) begin
                delta_odo = odos[i] - prev_odo;
              end else begin
                delta_odo = 32'd100000 - prev_odo + odos[i];
              end
              // Range checks for tampering
              min_odo = delta_months * 32'd2000;
              max_odo = delta_months * 32'd20000;
              if (delta_months == 0 || delta_odo < min_odo || delta_odo > max_odo) begin
                status <= 2'b10; // tampered odometer
              end else if (delta_months > 12 && delta_odo > 32'd30000) begin
                // Insufficient service interval
                if (status != 2'b10) status <= 2'b01;
              end
              // Update previous values
              prev_months <= months_curr;
              prev_odo <= odos[i];
            end
            i <= i + 1;
          end
          // Finish after processing all entries or after 10 cycles
          if (i == 3'b101) begin // i == 5
            state <= DONE;
          end else if (cycle_cnt == 4'b1001) begin // 9 cycles -> DONE
            state <= DONE;
          end
        end

        DONE: begin
          // Remain in DONE, status already set
        end
      endcase
    end
  end

endmodule
