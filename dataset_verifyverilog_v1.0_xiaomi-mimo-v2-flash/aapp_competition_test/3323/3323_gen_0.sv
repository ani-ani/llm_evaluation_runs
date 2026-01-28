module juice_mixing (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [13:0] A0, B0, C0,
    input wire [13:0] A1, B1, C1,
    input wire [13:0] A2, B2, C2,
    input wire [13:0] A3, B3, C3,
    input wire [13:0] A4, B4, C4,
    input wire [13:0] A5, B5, C5,
    input wire [13:0] A6, B6, C6,
    input wire [13:0] A7, B7, C7,
    input wire [13:0] A8, B8, C8,
    input wire [13:0] A9, B9, C9,
    input wire [13:0] A10, B10, C10,
    input wire [13:0] A11, B11, C11,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK_SUBSET = 3'd2;
    localparam [2:0] UPDATE_MAX = 3'd3;
    localparam [2:0] NEXT_SUBSET = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    
    // Data storage for 12 people
    reg [13:0] stored_A [0:11];
    reg [13:0] stored_B [0:11];
    reg [13:0] stored_C [0:11];
    
    // Subset iteration
    reg [11:0] current_subset;
    reg [11:0] max_subset;
    reg [3:0] max_size;
    reg [3:0] current_size;
    reg [13:0] max_A, max_B, max_C;
    reg [13:0] temp_A, temp_B, temp_C;
    reg [3:0] person_idx;
    
    // Intermediate results
    reg [14:0] sum_max;  // 15 bits for sum of three 14-bit values (max 30000)
    
    // Cycle counter to prevent infinite loops
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;
    
    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            current_subset <= 12'd0;
            max_subset <= 12'd0;
            max_size <= 4'd0;
            current_size <= 4'd0;
            max_A <= 14'd0;
            max_B <= 14'd0;
            max_C <= 14'd0;
            temp_A <= 14'd0;
            temp_B <= 14'd0;
            temp_C <= 14'd0;
            person_idx <= 4'd0;
            sum_max <= 15'd0;
            cycle_count <= 13'd0;
            // Initialize arrays
            for (i = 0; i < 12; i = i + 1) begin
                stored_A[i] <= 14'd0;
                stored_B[i] <= 14'd0;
                stored_C[i] <= 14'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    current_subset <= 12'd0;
                    max_subset <= 12'd0;
                    max_size <= 4'd0;
                end
                
                LOAD: begin
                    // Load all input data into storage
                    stored_A[0] <= A0; stored_B[0] <= B0; stored_C[0] <= C0;
                    stored_A[1] <= A1; stored_B[1] <= B1; stored_C[1] <= C1;
                    stored_A[2] <= A2; stored_B[2] <= B2; stored_C[2] <= C2;
                    stored_A[3] <= A3; stored_B[3] <= B3; stored_C[3] <= C3;
                    stored_A[4] <= A4; stored_B[4] <= B4; stored_C[4] <= C4;
                    stored_A[5] <= A5; stored_B[5] <= B5; stored_C[5] <= C5;
                    stored_A[6] <= A6; stored_B[6] <= B6; stored_C[6] <= C6;
                    stored_A[7] <= A7; stored_B[7] <= B7; stored_C[7] <= C7;
                    stored_A[8] <= A8; stored_B[8] <= B8; stored_C[8] <= C8;
                    stored_A[9] <= A9; stored_B[9] <= B9; stored_C[9] <= C9;
                    stored_A[10] <= A10; stored_B[10] <= B10; stored_C[10] <= C10;
                    stored_A[11] <= A11; stored_B[11] <= B11; stored_C[11] <= C11;
                    current_subset <= 12'd0;
                    current_size <= 4'd0;
                    person_idx <= 4'd0;
                    max_A <= 14'd0;
                    max_B <= 14'd0;
                    max_C <= 14'd0;
                    temp_A <= 14'd0;
                    temp_B <= 14'd0;
                    temp_C <= 14'd0;
                end
                
                CHECK_SUBSET: begin
                    // Calculate size and component-wise max for current subset
                    if (person_idx < N) begin
                        if (current_subset[person_idx]) begin
                            // Person is in subset, update max values
                            if (stored_A[person_idx] > max_A) max_A <= stored_A[person_idx];
                            if (stored_B[person_idx] > max_B) max_B <= stored_B[person_idx];
                            if (stored_C[person_idx] > max_C) max_C <= stored_C[person_idx];
                            current_size <= current_size + 4'd1;
                        end
                        person_idx <= person_idx + 4'd1;
                    end
                end
                
                UPDATE_MAX: begin
                    // Check if this subset is valid (sum <= 10000)
                    sum_max <= {1'b0, max_A} + {1'b0, max_B} + {1'b0, max_C};
                    if (sum_max <= 15'd10000 && current_size > max_size) begin
                        max_size <= current_size;
                        max_subset <= current_subset;
                    end
                end
                
                NEXT_SUBSET: begin
                    // Reset for next subset
                    current_subset <= current_subset + 12'd1;
                    current_size <= 4'd0;
                    person_idx <= 4'd0;
                    max_A <= 14'd0;
                    max_B <= 14'd0;
                    max_C <= 14'd0;
                    sum_max <= 15'd0;
                    cycle_count <= cycle_count + 13'd1;
                end
                
                FINISH: begin
                    result <= max_size;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                next_state = CHECK_SUBSET;
            end
            
            CHECK_SUBSET: begin
                if (person_idx >= N) begin
                    next_state = UPDATE_MAX;
                end else begin
                    next_state = CHECK_SUBSET;
                end
            end
            
            UPDATE_MAX: begin
                next_state = NEXT_SUBSET;
            end
            
            NEXT_SUBSET: begin
                // Check if we've processed all 2^N subsets or exceeded cycle limit
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (current_subset >= (12'd1 << N)) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SUBSET;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule