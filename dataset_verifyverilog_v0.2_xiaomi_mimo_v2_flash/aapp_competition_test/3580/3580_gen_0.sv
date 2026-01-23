module longest_valid_prefix (
    input clk,
    input rst_n,
    input start,
    input [3:0] start_index,
    input [7:0] b_data [0:7],
    input [3:0] b_size,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state, next_state;
    reg [3:0] idx;           // Current index in array a
    reg [3:0] count;         // Current count of valid prefix
    reg [3:0] next_count;
    reg is_member;           // Combinational flag: is a[idx] in b_data?

    // Hard-coded array 'a' (16 elements)
    wire [7:0] a [0:15];
    assign a[0] = 8'd1;
    assign a[1] = 8'd2;
    assign a[2] = 8'd3;
    assign a[3] = 8'd1;
    assign a[4] = 8'd2;
    assign a[5] = 8'd1;
    assign a[6] = 8'd1;
    assign a[7] = 8'd0;
    assign a[8] = 8'd0;
    assign a[9] = 8'd0;
    assign a[10] = 8'd0;
    assign a[11] = 8'd0;
    assign a[12] = 8'd0;
    assign a[13] = 8'd0;
    assign a[14] = 8'd0;
    assign a[15] = 8'd0;

    // Combinational Membership Check Logic
    // Checks if a[idx] matches any valid element in b_data (up to b_size)
    integer i;
    always @(*) begin
        is_member = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < b_size) begin
                if (a[idx] == b_data[i]) begin
                    is_member = 1'b1;
                end
            end
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                // Termination conditions:
                // 1. End of array (idx == 15, next index would be 16)
                // 2. Element not in B
                if (idx == 15 || !is_member)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 4'd0;
            count <= 4'd0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize computation
                        idx <= start_index;
                        // Check immediate validity of start_index element for initial count
                        // Note: is_member is combinational based on current idx, which is start_index now
                        if (is_member) begin
                            count <= 4'd1;
                        end else begin
                            count <= 4'd0;
                        end
                    end
                end

                COMPUTE: begin
                    // Increment index for next cycle
                    idx <= idx + 1;
                    
                    // Update count if current element is valid
                    if (is_member) begin
                        count <= count + 1;
                    end
                    // If current state is COMPUTE but next_state is DONE (termination condition met this cycle),
                    // the output 'result' will be updated in the DONE state logic below.
                end

                DONE: begin
                    done <= 1'b1;
                    // Latch the calculated result
                    // If we arrived here from COMPUTE, 'count' holds the total valid length
                    result <= count;
                    
                    // If a new start comes in the same cycle (handshake style), prepare for it
                    if (start) begin
                        done <= 1'b0;
                        idx <= start_index;
                        if (is_member) count <= 4'd1; else count <= 4'd0;
                    end
                end
            endcase
        end
    end

endmodule
