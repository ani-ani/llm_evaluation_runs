module star_wars_movies #(
    parameter MAX_MOVIES = 16,
    parameter MAX_QUERIES = 256
) (
    input clk,
    input rst_n,
    input start,
    input [1:0] query_type,
    input [7:0] query_value,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PROCESS_QUERY = 3'b001;
    localparam INSERT_SHIFT = 3'b010;
    localparam INSERT_WRITE = 3'b011;
    localparam LOOKUP = 3'b100;
    localparam DONE_STATE = 3'b101;

    // Registers for state and datapath
    reg [2:0] state;
    reg [7:0] n; // Current number of movies
    reg [7:0] movies [0:MAX_MOVIES-1]; // Movie array
    reg [7:0] idx; // Loop index/counter
    reg [7:0] creation_idx; // Temporary storage for creation index
    reg [1:0] op_type; // Store query type
    reg [7:0] op_val; // Store query value

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            done <= 1'b0;
            n <= 8'b0;
            idx <= 8'b0;
            creation_idx <= 8'b0;
            op_type <= 2'b0;
            op_val <= 8'b0;
            // Initialize memory (optional but good practice for clean reset)
            for (i = 0; i < MAX_MOVIES; i = i + 1) begin
                movies[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        op_type <= query_type;
                        op_val <= query_value;
                        state <= PROCESS_QUERY;
                    end
                end

                PROCESS_QUERY: begin
                    if (op_type == 2'b01) begin // Insert
                        // Check if array is full
                        if (n < MAX_MOVIES) begin
                            creation_idx <= n + 1; // New creation index
                            idx <= n; // Start from end of array
                            state <= INSERT_SHIFT;
                        end else begin
                            // Array full, fail gracefully or return error
                            result <= 8'hFF; // Indicate error/full
                            state <= DONE_STATE;
                        end
                    end else if (op_type == 2'b10) begin // Lookup
                        // Check bounds
                        if (op_val > 0 && op_val <= n) begin
                            state <= LOOKUP;
                        end else begin
                            result <= 8'h00; // Out of bounds
                            state <= DONE_STATE;
                        end
                    end else begin
                        // Invalid query type
                        state <= DONE_STATE;
                    end
                end

                INSERT_SHIFT: begin
                    // Shift elements: movies[idx] = movies[idx-1] (conceptually)
                    // Since we iterate downwards from n-1 to x-1, we read from idx-1 and write to idx
                    // But we need to store the value being overwritten if we were doing in-place.
                    // However, we are using a temporary 'creation_idx' that evolves.
                    // Algorithm: 
                    //   temp = new_creation_idx
                    //   loop i from val-1 to n-1:
                    //     swap(temp, movies[i])
                    //   We are effectively doing: 
                    //   movies[i+1] = movies[i] for i from n-1 down to val-1.
                    //   Wait, the provided example: Shift movies[0]->movies[1] implies direction is up.
                    //   Array is contiguous [0..n-1]. Insert at x (1-indexed) means index x-1.
                    //   Items at x-1, x, ... n-1 shift to x, x+1, ... n.
                    //   So we loop i from n down to x.
                    //   movies[i] = movies[i-1].
                    //   Requires 'idx' to point to the destination.
                    //   We will use 'idx' as the destination index. Start at n, go down to op_val.
                    //   Boundary: array size N=MAX_MOVIES. We cannot write beyond MAX_MOVIES-1.
                    //   Since we check n < MAX_MOVIES, the new max index is n, which is valid (0..n-1 existing, new slot n).
                    //   Actually, array indices are 0..MAX_MOVIES-1. 
                    //   If n=1, indices 0 used. New item at x=1 -> index 0. Shift? No, items >= x shift.
                    //   If x=1, we shift items >=1 (i.e., none if n=0). 
                    //   Let's refine logic:
                    //   We want to shift movies from index (x-1) to (n-1) up by 1.
                    //   Loop variable 'i' goes from n-1 down to x-1. 
                    //   movies[i+1] = movies[i].
                    //   Register 'idx' will be the destination index i+1.
                    //   Initial state of INSERT_SHIFT: idx = n (destination for the last element).
                    //   Wait, if n=0, we don't enter shift if x=1? 
                    //   If n=0, insertion is direct. 
                    //   If n > 0.
                    //   Example: n=2, insert x=1. Shift indices 0,1 to 1,2. 
                    //   i goes from 1 down to 0. 
                    //   movies[2] = movies[1]; 
                    //   movies[1] = movies[0];
                    //   Then insert at movies[0].
                    //   So we need a counter 'i' for the source index.
                    //   Let's use 'idx' as the source index (i).
                    //   Start idx = n - 1. Condition: idx >= op_val - 1.
                    //   Action: movies[idx + 1] = movies[idx]. Then decrement idx.
                    //   When idx < op_val - 1, shift done.
                    //   Transition to INSERT_WRITE.
                    
                    if (idx > op_val - 1) begin
                        movies[idx] <= movies[idx - 1]; // Shift down
                        idx <= idx - 1;
                        state <= INSERT_SHIFT;
                    end else begin
                        state <= INSERT_WRITE;
                    end
                end

                INSERT_WRITE: begin
                    // Write new creation index at plot position op_val - 1
                    movies[op_val - 1] <= creation_idx;
                    n <= n + 1;
                    result <= creation_idx; // Return confirmation (creation index)
                    state <= DONE_STATE;
                end

                LOOKUP: begin
                    // Read from index op_val - 1
                    result <= movies[op_val - 1];
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to avoid auto-retrigger if not handled externally
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
