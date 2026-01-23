module coin_change_max (
  input clk,
  input rst_n,
  input start,
  input [15:0] price,
  input [6:0] n1,
  input [6:0] n5,
  input [6:0] n10,
  input [6:0] n25,
  output reg [15:0] max_coins,
  output reg done,
  output reg impossible
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] INIT = 3'b001;
  localparam [2:0] COIN_1 = 3'b010;
  localparam [2:0] COIN_5 = 3'b011;
  localparam [2:0] COIN_10 = 3'b100;
  localparam [2:0] COIN_25 = 3'b101;
  localparam [2:0] VERIFY = 3'b110;
  localparam [2:0] DONE = 3'b111;

  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // DP table: 1024 entries (0-1023), 16-bit each
  reg [15:0] dp [0:1023];
  reg [9:0] amount = 0;
  reg [6:0] k = 0;
  reg [15:0] current_max = 0;
  reg [15:0] temp_value = 0;

  // Counters for coin processing
  reg [9:0] amount_counter = 0;
  reg [6:0] k_counter = 0;
  reg [15:0] denom = 0;
  reg [6:0] coin_count = 0;

  // Control signals
  reg init_done = 0;
  reg coin_process_done = 0;

  // Invalid value marker (0xFFFF)
  localparam INVALID = 16'hFFFF;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      max_coins <= 0;
      init_done <= 0;
      coin_process_done <= 0;
      amount_counter <= 0;
      k_counter <= 0;
      denom <= 0;
      coin_count <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        if (init_done) next_state = COIN_1;
      end
      COIN_1: begin
        if (coin_process_done) next_state = COIN_5;
      end
      COIN_5: begin
        if (coin_process_done) next_state = COIN_10;
      end
      COIN_10: begin
        if (coin_process_done) next_state = COIN_25;
      end
      COIN_25: begin
        if (coin_process_done) next_state = VERIFY;
      end
      VERIFY: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // DP table initialization
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (integer i = 0; i < 1024; i = i + 1) begin
        dp[i] <= INVALID;
      end
      init_done <= 0;
    end else if (state == INIT) begin
      if (amount == 0) begin
        dp[0] <= 0;
        amount <= amount + 1;
      end else if (amount < 1024) begin
        dp[amount] <= INVALID;
        amount <= amount + 1;
      end else begin
        init_done <= 1;
        amount <= 0;
      end
    end
  end

  // Coin processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      amount_counter <= 0;
      k_counter <= 0;
      coin_process_done <= 0;
    end else if (state == COIN_1 || state == COIN_5 || state == COIN_10 || state == COIN_25) begin
      case (state)
        COIN_1: begin denom = 1; coin_count = n1; end
        COIN_5: begin denom = 5; coin_count = n5; end
        COIN_10: begin denom = 10; coin_count = n10; end
        COIN_25: begin denom = 25; coin_count = n25; end
      endcase

      if (amount_counter == 0 && k_counter == 0) begin
        // Start processing
        if (amount_counter < price + 1) begin
          amount_counter <= amount_counter + 1;
        end
      end else if (amount_counter < price + 1) begin
        if (k_counter == 0) begin
          // Move to next amount
          amount_counter <= amount_counter + 1;
        end else if (k_counter < coin_count && 
                   amount_counter + k_counter * denom <= price &&
                   dp[amount_counter] != INVALID) begin
          temp_value = dp[amount_counter + k_counter * denom];
          current_max = dp[amount_counter] + k_counter;
          if (temp_value == INVALID || current_max > temp_value) begin
            dp[amount_counter + k_counter * denom] <= current_max;
          end
          k_counter <= k_counter + 1;
        end else if (k_counter >= coin_count || amount_counter + k_counter * denom > price) begin
          k_counter <= 0;
        end
      end else begin
        coin_process_done <= 1;
        amount_counter <= 0;
        k_counter <= 0;
      end
    end
  end

  // Verification and output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      impossible <= 0;
      max_coins <= 0;
    end else if (state == VERIFY) begin
      if (dp[price] == INVALID) begin
        impossible <= 1;
        max_coins <= INVALID;
      end else begin
        impossible <= 0;
        max_coins <= dp[price];
      end
      done <= 1;
    end else if (state == DONE) begin
      if (!start) begin
        done <= 0;
        impossible <= 0;
        max_coins <= 0;
      end
    end
  end

endmodule