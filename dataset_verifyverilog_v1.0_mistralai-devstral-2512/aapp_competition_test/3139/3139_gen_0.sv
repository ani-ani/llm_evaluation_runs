module student_helper(
    input clk,
    input rst_n,
    input start,
    input op_type,
    input [3:0] idx,
    input [15:0] A_in,
    input [15:0] B_in,
    output reg [3:0] result_idx,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] ADD = 4'd1;
    localparam [3:0] QUERY_INIT = 4'd2;
    localparam [3:0] QUERY_SEARCH = 4'd3;
    localparam [3:0] QUERY_DONE = 4'd4;

    // Storage arrays and valid bitmask
    reg [15:0] A_mem [0:15];
    reg [15:0] B_mem [0:15];
    reg [15:0] students_present;
    reg [3:0] student_count;

    // Query state machine variables
    reg [3:0] state;
    reg [3:0] current_idx;
    reg [3:0] best_idx;
    reg [15:0] best_diff_B;
    reg [15:0] best_diff_A;
    reg [15:0] A_query;
    reg [15:0] B_query;
    reg [3:0] query_idx;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result_idx <= 4'd0;
            student_count <= 4'd0;
            students_present <= 16'd0;
            
            // Initialize memory arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                A_mem[i] <= 16'd0;
                B_mem[i] <= 16'd0;
            end
            
            // Initialize query variables
            current_idx <= 4'd0;
            best_idx <= 4'd0;
            best_diff_B <= 16'd0;
            best_diff_A <= 16'd0;
            A_query <= 16'd0;
            B_query <= 16'd0;
            query_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        if (op_type == 1'b0) begin
                            state <= ADD;
                        end else begin
                            state <= QUERY_INIT;
                        end
                    end
                end

                ADD: begin
                    // Find first available slot
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (students_present[i] == 1'b0) begin
                            A_mem[i] <= A_in;
                            B_mem[i] <= B_in;
                            students_present[i] <= 1'b1;
                            student_count <= student_count + 4'd1;
                            break;
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                QUERY_INIT: begin
                    // Store query parameters
                    query_idx <= idx;
                    A_query <= A_in;
                    B_query <= B_in;
                    
                    // Initialize search variables
                    current_idx <= 4'd0;
                    best_idx <= 4'd0;
                    best_diff_B <= 16'd32767; // Max value
                    best_diff_A <= 16'd32767; // Max value
                    
                    state <= QUERY_SEARCH;
                end

                QUERY_SEARCH: begin
                    // Check if we've searched all students
                    if (current_idx == 4'd16) begin
                        state <= QUERY_DONE;
                    end else begin
                        // Check if current student is valid and not the query student
                        if (students_present[current_idx] && (current_idx != (query_idx - 4'd1))) begin
                            // Check dominance condition
                            if (A_mem[current_idx] >= A_query && B_mem[current_idx] >= B_query) begin
                                // Calculate differences
                                reg [15:0] diff_B = B_mem[current_idx] - B_query;
                                reg [15:0] diff_A = A_mem[current_idx] - A_query;
                                
                                // Check if this is better than current best
                                if (diff_B < best_diff_B || (diff_B == best_diff_B && diff_A < best_diff_A)) begin
                                    best_diff_B <= diff_B;
                                    best_diff_A <= diff_A;
                                    best_idx <= current_idx + 4'd1; // 1-based index
                                end
                            end
                        end
                        current_idx <= current_idx + 4'd1;
                    end
                end

                QUERY_DONE: begin
                    // Set result
                    if (best_idx == 4'd0) begin
                        result_idx <= 4'd0; // NE
                        valid <= 1'b0;
                    end else begin
                        result_idx <= best_idx;
                        valid <= 1'b1;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule