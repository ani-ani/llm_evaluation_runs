module pokemon_gcd (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] pokemon_strength [0:7],
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    COUNT_FACTORS,
    FIND_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Prime numbers up to 255 (32 primes)
  localparam [7:0] prime [0:31] = '{8'd2, 8'd3, 8'd5, 8'd7, 8'd11, 8'd13, 8'd17, 8'd19, 8'd23, 8'd29,
                                          8'd31, 8'd37, 8'd41, 8'd43, 8'd47, 8'd53, 8'd59, 8'd61, 8'd67, 8'd71,
                                          8'd73, 8'd79, 8'd83, 8'd89, 8'd97, 8'd101, 8'd103, 8'd107, 8'd109, 8'd113,
                                          8'd127, 8'd131};

  // Count array for each prime
  reg [7:0] count [0:31];

  // Counters
  reg [2:0] pokemon_idx;
  reg [4:0] prime_idx;
  reg [7:0] max_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 0;
      pokemon_idx <= 0;
      prime_idx <= 0;
      max_count <= 0;
      for (int i = 0; i < 32; i++) begin
        count[i] <= 0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD;
        end
      end

      LOAD: begin
        next_state = COUNT_FACTORS;
      end

      COUNT_FACTORS: begin
        if (pokemon_idx == n - 1 && prime_idx == 31) begin
          next_state = FIND_MAX;
        end
      end

      FIND_MAX: begin
        if (prime_idx == 31) begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        LOAD: begin
          pokemon_idx <= 0;
          prime_idx <= 0;
        end

        COUNT_FACTORS: begin
          if (pokemon_strength[pokemon_idx] % prime[prime_idx] == 0) begin
            count[prime_idx] <= count[prime_idx] + 1;
          end

          if (prime_idx == 31) begin
            pokemon_idx <= pokemon_idx + 1;
            prime_idx <= 0;
          end else begin
            prime_idx <= prime_idx + 1;
          end
        end

        FIND_MAX: begin
          if (count[prime_idx] > max_count) begin
            max_count <= count[prime_idx];
          end

          if (prime_idx == 31) begin
            result <= max_count > 0 ? max_count : 1;
            done <= 1;
          end else begin
            prime_idx <= prime_idx + 1;
          end
        end

        DONE: begin
          if (!start) begin
            done <= 0;
          end
        end

        default: ;
      endcase
    end
  end

endmodule