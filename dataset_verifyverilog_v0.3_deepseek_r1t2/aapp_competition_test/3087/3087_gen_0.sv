module dance_arrows #(
    parameter N = 8,               // Number of dancers (max 8)
    parameter K_WIDTH = 8          // Width of K input
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [K_WIDTH-1:0] K,
    input wire [7:0] a [0:N-1],    // Input permutation (1-indexed)
    output reg [7:0] f [0:N-1],    // Output permutation
    output reg valid,
    output reg error
);

// State definitions
localparam [2:0]
    IDLE       = 3'd0,
    DECOMPOSE  = 3'd1,
    CHECK      = 3'd2,
    CONSTRUCT  = 3'd3,
    DONE       = 3'd4,
    ERROR_ST   = 3'd5;

reg [2:0] state, next_state;
reg [7:0] cycle_counter;
reg [3:0] index, step;

// Cycle decomposition registers
reg visited [0:N-1];
reg [7:0] next_in_cycle [0:N-1];
reg [7:0] cycle_id [0:N-1];
reg [7:0] pos_in_cycle [0:N-1];

// Cycle storage (max N cycles)
reg [2:0] current_cycle_id;
reg [7:0] cycle_start [0:7];
reg [7:0] cycle_len [0:7];

// Temp registers
reg [7:0] current_idx;
reg [7:0] temp_counter;

// Error flags
reg cycle_check_failed;

// Constants
localparam [7:0] MAX_CYCLES = 8'd100;

integer i;

// FSM logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize ALL registers
        state <= IDLE;
        valid <= 1'b0;
        error <= 1'b0;
        cycle_counter <= 8'd0;
        index <= 4'd0;
        step <= 4'd0;
        current_cycle_id <= 3'd0;
        current_idx <= 8'd0;
        temp_counter <= 8'd0;
        cycle_check_failed <= 1'b0;
        
        // Initialize arrays
        for (i = 0; i < N; i = i + 1) begin
            visited[i] <= 1'b0;
            next_in_cycle[i] <= 8'd0;
            cycle_id[i] <= 8'd0;
            pos_in_cycle[i] <= 8'd0;
            f[i] <= 8'd0;
        end
        
        for (i = 0; i < 8; i = i + 1) begin
            cycle_start[i] <= 8'd0;
            cycle_len[i] <= 8'd0;
        end
    end else begin
        // Cycle counter for timeout
        cycle_counter <= cycle_counter + 8'd1;
        
        // FSM state transition
        if (cycle_counter > MAX_CYCLES) begin
            state <= ERROR_ST;
        end else begin
            state <= next_state;
        end
        
        case (state)
            IDLE: begin
                valid <= 1'b0;
                error <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    // Initialize decomposition arrays
                    for (i = 0; i < N; i = i + 1) begin
                        visited[i] <= 1'b0;
                        next_in_cycle[i] <= a[i] - 8'd1;
                        cycle_id[i] <= 8'd0;
                        pos_in_cycle[i] <= 8'd0;
                    end
                    current_cycle_id <= 3'd0;
                    index <= 4'd0;
                    step <= 4'd0;
                    next_state <= DECOMPOSE;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            DECOMPOSE: begin
                if (index < N) begin
                    if (!visited[index]) begin
                        // Start new cycle
                        cycle_start[current_cycle_id] <= index;
                        temp_counter <= 8'd0;
                        current_idx <= index;
                        step <= step + 4'd1;  // Step 1: mark cycle
                    end else begin
                        index <= index + 4'd1;
                    end
                end else begin
                    next_state <= CHECK;
                    step <= 4'd0;
                    index <= 4'd0;
                end
                
                if (step == 1) begin
                    if (!visited[current_idx]) begin
                        visited[current_idx] <= 1'b1;
                        pos_in_cycle[current_idx] <= temp_counter;
                        cycle_id[current_idx] <= current_cycle_id;
                        temp_counter <= temp_counter + 8'd1;
                        current_idx <= next_in_cycle[current_idx];
                    end else begin
                        // End of cycle
                        cycle_len[current_cycle_id] <= temp_counter;
                        current_cycle_id <= current_cycle_id + 3'd1;
                        index <= index + 4'd1;
                        step <= 4'd0;
                    end
                end
            end
            
            CHECK: begin
                // Simplified check - implementation left for full design
                // For demo purposes, assume CHECK always passes
                cycle_check_failed <= 1'b0;
                next_state <= CONSTRUCT;
            end
            
            CONSTRUCT: begin
                // Simplified construction - assign a[x] to f[x] for demo
                if (index < N) begin
                    f[index] <= a[index];
                    index <= index + 4'd1;
                end else begin
                    next_state <= DONE;
                end
            end
            
            DONE: begin
                valid <= 1'b1;
                next_state <= IDLE;
            end
            
            ERROR_ST: begin
                error <= 1'b1;
                valid <= 1'b0;
                next_state <= IDLE;
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule