module shortest_cycle_detector(
  input clk,
  input rst_n,
  input start,
  input [15:0] a0,
  input [15:0] a1,
  input [15:0] a2,
  input [15:0] a3,
  input [15:0] a4,
  input [15:0] a5,
  input [15:0] a6,
  input [15:0] a7,
  output reg [4:0] cycle_len,
  output reg done
);

localparam WIDTH = 8;
localparam COUNTER_MAX = 7'd49;
typedef enum {IDLE, BUILD_GRAPH, SEARCH_CYCLES, DONE} state_t;

state_t state, next_state;
reg [6:0] cycle_counter;

// Captured input vectors
reg [15:0] captured_a[0:7];
// Adjacency matrix
reg [7:0] adj [0:7];
// Matrices for A^2 to A^8
reg [7:0] A[0:7][0:7];
reg [7:0] next_A[0:7][0:7];
reg [4:0] min_cycle;
reg [2:0] k_counter;

integer i, j, m;

// FSM state transition
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
  end else begin
    state <= next_state;
  end
end

// Cycle counter
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cycle_counter <= 0;
  end else begin
    if (state == IDLE)
      cycle_counter <= 0;
    else if (cycle_counter < COUNTER_MAX)
      cycle_counter <= cycle_counter + 1;
    else
      cycle_counter <= 0;
  end
end

// FSM next state logic
always_comb begin
  next_state = state;
  case(state)
    IDLE: if (start) next_state = BUILD_GRAPH;
    BUILD_GRAPH: next_state = SEARCH_CYCLES;
    SEARCH_CYCLES: begin
      if (cycle_counter == COUNTER_MAX)
        next_state = DONE;
      else
        next_state = SEARCH_CYCLES;
    end
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

// Capture input vectors
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (i = 0; i < WIDTH; i = i + 1)
      captured_a[i] <= 0;
  end else if (state == BUILD_GRAPH) begin
    captured_a[0] <= a0;
    captured_a[1] <= a1;
    captured_a[2] <= a2;
    captured_a[3] <= a3;
    captured_a[4] <= a4;
    captured_a[5] <= a5;
    captured_a[6] <= a6;
    captured_a[7] <= a7;
  end
end

// Build adjacency matrix
always_comb begin
    for (i = 0; i < WIDTH; i = i + 1) begin
        for (j = 0; j < WIDTH; j = j + 1) begin
            if (i != j)
                adj[i][j] = (captured_a[i] & captured_a[j]) != 0;
            else
                adj[i][j] = 0;
        end
    end
end

// Initialize and update matrices
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (i = 0; i < WIDTH; i = i + 1) begin
        for (j = 0; j < WIDTH; j = j + 1) begin
            A[i][j] <= 0;
        end
    end
    k_counter <= 0;
    min_cycle <= 0;
  end else begin
    case(state)
      BUILD_GRAPH: begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            for (j = 0; j < WIDTH; j = j + 1) begin
                A[i][j] <= adj[i][j];
            end
        end
        k_counter <= 3;
        min_cycle <= 0;
      end
      SEARCH_CYCLES: begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            for (j = 0; j < WIDTH; j = j + 1) begin
                A[i][j] <= next_A[i][j];
            end
        end
        // Check diagonal
        if (min_cycle == 0) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (A[i][i]) begin
                    min_cycle <= k_counter;
                end
            end
        end
        if (k_counter < 8) begin
            k_counter <= k_counter + 1;
        end
      end
      default: begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            for (j = 0; j < WIDTH; j = j + 1) begin
                A[i][j] <= 0;
            end
        end
        k_counter <= 0;
        min_cycle <= 0;
      end
    endcase
  end
end

// Matrix multiplication
always_comb begin
  for (i = 0; i < WIDTH; i = i + 1) begin
    for (j = 0; j < WIDTH; j = j + 1) begin
        next_A[i][j] = 0;
        for (m = 0; m < WIDTH; m = m + 1) begin
            if (state == SEARCH_CYCLES)
                next_A[i][j] = next_A[i][j] | (A[i][m] & adj[m][j]);
        end
    end
  end
end

// Output assignment
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cycle_len <= 0;
    done <= 0;
  end else begin
    done <= 0;
    if (state == DONE) begin
        done <= 1;
        if (min_cycle != 0)
            cycle_len <= min_cycle;
        else
            cycle_len <= 0;
    end
  end
end

endmodule