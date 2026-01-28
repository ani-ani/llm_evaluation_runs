module student_helper (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,
    input wire [3:0] idx,
    input wire [15:0] A_in,
    input wire [15:0] B_in,
    output reg [3:0] result_idx,
    output reg done,
    output reg valid
);

    // Memory storage
    reg [15:0] A_mem [0:15];
    reg [15:0] B_mem [0:15];
    reg [15:0] students_present;
    reg [3:0] student_count;

    // Search state
    reg [3:0] search_idx;
    reg [3:0] best_idx;
    reg [31:0] best_delta;  // Packed: {A_delta[15:0], B_delta[15:0]}
    reg query_active;
    reg [15:0] query_A;
    reg [15:0] query_B;

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ADD     = 2'd1;
    localparam [1:0] QUERY   = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    reg [1:0] state, next_state;

    // Combinational logic for dominance check
    wire A_dom, B_dom;
    assign A_dom = (A_mem[search_idx] >= query_A);
    assign B_dom = (B_mem[search_idx] >= query_B);
    wire dominance = A_dom & B_dom;

    // Delta calculation (unsigned)
    wire [15:0] delta_A = A_mem[search_idx] - query_A;
    wire [15:0] delta_B = B_mem[search_idx] - query_B;
    wire [31:0] current_delta = {delta_A, delta_B};

    // Better check: minimize B_delta first, then A_delta
    wire better_B = (delta_B < best_delta[15:0]);
    wire better_A = (delta_A < best_delta[31:16]);
    wire better = dominance & (better_B | (delta_B == best_delta[15:0] & better_A));

    // FSM next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (op_type == 1'b0) begin
                        next_state = ADD;
                    end else begin
                        next_state = QUERY;
                    end
                end
            end
            ADD: begin
                next_state = DONE;
            end
            QUERY: begin
                if (search_idx >= 4'd15) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset memory and state
            for (i = 0; i < 16; i = i + 1) begin
                A_mem[i] <= 16'd0;
                B_mem[i] <= 16'd0;
            end
            students_present <= 16'd0;
            student_count <= 4'd0;
            state <= IDLE;
            result_idx <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            query_active <= 1'b0;
            search_idx <= 4'd0;
            best_idx <= 4'd0;
            best_delta <= 32'hFFFF_FFFF;
            query_A <= 16'd0;
            query_B <= 16'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (op_type == 1'b0) begin
                            // ADD operation
                            // Find first available slot
                            if (student_count < 4'd16) begin
                                A_mem[student_count] <= A_in;
                                B_mem[student_count] <= B_in;
                                students_present[student_count] <= 1'b1;
                            end
                        end else begin
                            // QUERY operation
                            query_active <= 1'b1;
                            query_A <= A_in;
                            query_B <= B_in;
                            search_idx <= 4'd0;
                            best_idx <= 4'd0;  // 0 means NE
                            best_delta <= 32'hFFFF_FFFF;
                        end
                    end
                end
                
                ADD: begin
                    if (student_count < 4'd16) begin
                        student_count <= student_count + 4'd1;
                    end
                    result_idx <= 4'd0;
                    valid <= 1'b0;
                    done <= 1'b1;
                end
                
                QUERY: begin
                    // Only process valid students
                    if (students_present[search_idx] && search_idx != (idx - 4'd1)) begin
                        if (better) begin
                            best_idx <= search_idx;
                            best_delta <= current_delta;
                        end
                    end
                    
                    search_idx <= search_idx + 4'd1;
                    
                    // Check if we're done with search
                    if (search_idx >= 4'd15) begin
                        // Search complete, go to DONE next cycle
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (query_active) begin
                        // Check for invalid query index
                        if (idx > student_count || idx == 4'd0) begin
                            result_idx <= 4'd0;
                            valid <= 1'b0;
                        end else if (best_idx == 4'd0) begin
                            // No dominant student found
                            result_idx <= 4'd0;
                            valid <= 1'b0;
                        end else begin
                            result_idx <= best_idx + 4'd1;
                            valid <= 1'b1;
                        end
                        query_active <= 1'b0;
                    end else begin
                        // Add operation
                        result_idx <= 4'd0;
                        valid <= 1'b0;
                    end
                end
                
                default: begin
                    // Should not happen
                    state <= IDLE;
                    done <= 1'b0;
                    query_active <= 1'b0;
                end
            endcase
        end
    end

endmodule