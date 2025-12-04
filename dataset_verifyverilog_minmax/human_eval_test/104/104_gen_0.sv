module unique_digits_filter #(
  parameter W = 16
) (
  input  wire               clk,
  input  wire               rst_n,
  input  wire               start,
  input  wire [3:0][W-1:0]  numbers,
  output reg  [3:0][W-1:0]  sorted_out,
  output reg  [3:0]         valid_mask
);

  // Helper: pure combinational check if all base-10 digits are odd (1,3,5,7,9)
  function automatic bits all_odd_digits;
    input [W-1:0] x;
    integer i;
    begin
      all_odd_digits = 1'b1;
      for (i = 0; i < W; i = i + 1) begin
        if ((x / (10**i)) == 0) break; // reached most significant non-zero digit
        if (((x / (10**i)) % 10) % 2 == 0) begin
          all_odd_digits = 1'b0;
          break;
        end
      end
    end
  endfunction

  // Internal pipeline for sorting
  reg [3:0][W-1:0] data_r;
  reg [3:0]        mask_r;

  // Control FSM
  typedef enum logic [1:0] {ST_IDLE = 2'b00, ST_PROC = 2'b01, ST_DONE = 2'b10} state_t;
  state_t state, next_state;

  reg [3:0] step_cnt; // 4 steps (0..3) to guarantee 10 cycles total
  wire step_done;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Combinational next-state logic
  always_comb begin
    case (state)
      ST_IDLE: next_state = start ? ST_PROC : ST_IDLE;
      ST_PROC: next_state = step_done ? ST_DONE : ST_PROC;
      ST_DONE: next_state = ST_IDLE;
      default: next_state = ST_IDLE;
    endcase
  end

  // Step counter logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      step_cnt <= 4'b0;
    end else begin
      if (state == ST_PROC) begin
        step_cnt <= step_cnt + 1;
      end else begin
        step_cnt <= 4'b0;
      end
    end
  end
  assign step_done = (step_cnt == 4'd3); // 4 steps -> 10 cycles total (1 load + 9 comp-swaps)

  // Compute valid mask combinatorially (digit check)
  wire [3:0] valid_mask_comb;
  assign valid_mask_comb = {
    all_odd_digits(numbers[3]),
    all_odd_digits(numbers[2]),
    all_odd_digits(numbers[1]),
    all_odd_digits(numbers[0])
  };

  // Bubble-sort compare-swap network (9 compare-swaps over 4 steps)
  // Each step performs 3 swaps; step_cnt encodes which layer of the network.
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : CLOCKED_DATA
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          data_r[i] <= {W{1'b0}};
          mask_r[i] <= 1'b0;
        end else begin
          if (state == ST_IDLE) begin
            // Latch inputs at start of ST_PROC
            data_r[i] <= numbers[i];
            mask_r[i] <= valid_mask_comb[i];
          end else if (state == ST_PROC) begin
            // In-place compare-swap per step layer
            data_r[i] <= data_r[i];
            mask_r[i] <= mask_r[i];
            if (step_cnt == 4'd0) begin // Layer 0: (0,1), (2,3)
              if (i == 0 || i == 1) begin
                if (mask_r[i] && mask_r[i+1]) begin
                  if (data_r[i] > data_r[i+1]) begin
                    data_r[i]   <= data_r[i+1];
                    data_r[i+1] <= data_r[i];
                  end
                end
              end
            end else if (step_cnt == 4'd1) begin // Layer 1: (1,2)
              if (i == 1) begin
                if (mask_r[i] && mask_r[i+1]) begin
                  if (data_r[i] > data_r[i+1]) begin
                    data_r[i]   <= data_r[i+1];
                    data_r[i+1] <= data_r[i];
                  end
                end
              end
            end else if (step_cnt == 4'd2) begin // Layer 2: (0,1), (2,3)
              if (i == 0 || i == 1) begin
                if (mask_r[i] && mask_r[i+1]) begin
                  if (data_r[i] > data_r[i+1]) begin
                    data_r[i]   <= data_r[i+1];
                    data_r[i+1] <= data_r[i];
                  end
                end
              end
            end else if (step_cnt == 4'd3) begin // Layer 3: (1,2)
              if (i == 1) begin
                if (mask_r[i] && mask_r[i+1]) begin
                  if (data_r[i] > data_r[i+1]) begin
                    data_r[i]   <= data_r[i+1];
                    data_r[i+1] <= data_r[i];
                  end
                end
              end
            end
          end
        end
      end
    end
  endgenerate

  // Output registration
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sorted_out <= {4{{W{1'b0}}}};
      valid_mask <= 4'b0;
    end else begin
      if (state == ST_IDLE) begin
        // Latch new results (stable during DONE)
        sorted_out <= data_r;
        valid_mask <= mask_r;
      end else if (state == ST_DONE) begin
        // Keep latched outputs stable in DONE
        sorted_out <= sorted_out;
        valid_mask <= valid_mask;
      end
    end
  end

endmodule
