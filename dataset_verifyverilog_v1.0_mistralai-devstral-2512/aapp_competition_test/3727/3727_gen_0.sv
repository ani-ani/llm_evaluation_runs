module beautiful_sequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    input wire [15:0] d,
    output reg result_valid,
    output reg [7:0] result,
    output reg [15:0] result_index,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STATE_0 = 2'd1;
    localparam [1:0] STATE_1 = 2'd2;
    localparam [1:0] STATE_2 = 2'd3;
    localparam [1:0] STATE_3 = 2'd0; // Reusing IDLE value for STATE_3

    reg [1:0] state, next_state;
    reg [15:0] count_0, count_1, count_2, count_3;
    reg [15:0] index;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd100050;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count_0 <= 16'd0;
            count_1 <= 16'd0;
            count_2 <= 16'd0;
            count_3 <= 16'd0;
            index <= 16'd0;
            result_valid <= 1'b0;
            result <= 8'd0;
            result_index <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 16'd0;
                    
                    if (start) begin
                        // Load counts
                        count_0 <= a;
                        count_1 <= b;
                        count_2 <= c;
                        count_3 <= d;
                        index <= 16'd0;
                        result_index <= 16'd0;
                        
                        // Check if sequence is possible
                        if ((a == 16'd0 && b == 16'd0 && c == 16'd0 && d == 16'd0) ||
                            (a == 16'd0 && b == 16'd0 && c > 16'd0 && d == 16'd0) ||
                            (a > 16'd0 && b == 16'd0 && c == 16'd0 && d == 16'd0) ||
                            (a == 16'd0 && b > 16'd0 && c == 16'd0 && d > 16'd0) ||
                            (a > 16'd0 && b == 16'd0 && c > 16'd0 && d == 16'd0) ||
                            (a > 16'd0 && b > 16'd0 && c == 16'd0 && d == 16'd0) ||
                            (a == 16'd0 && b == 16'd0 && c == 16'd0 && d > 16'd0) ||
                            (a > 16'd0 && b == 16'd0 && c == 16'd0 && d > 16'd0) ||
                            (a == 16'd0 && b > 16'd0 && c > 16'd0 && d == 16'd0) ||
                            (a == 16'd0 && b > 16'd0 && c == 16'd0 && d == 16'd0) ||
                            (a == 16'd0 && b == 16'd0 && c > 16'd0 && d > 16'd0) ||
                            (a > 16'd0 && b > 16'd0 && c > 16'd0 && d == 16'd0) ||
                            (a > 16'd0 && b > 16'd0 && c == 16'd0 && d > 16'd0) ||
                            (a > 16'd0 && b == 16'd0 && c > 16'd0 && d > 16'd0) ||
                            (a == 16'd0 && b > 16'd0 && c > 16'd0 && d > 16'd0)) begin
                            impossible <= 1'b1;
                        end else begin
                            // Determine starting state
                            if (count_0 > 16'd0) begin
                                next_state <= STATE_0;
                            end else if (count_3 > 16'd0) begin
                                next_state <= STATE_3;
                            end else if (count_1 > 16'd0) begin
                                next_state <= STATE_1;
                            end else if (count_2 > 16'd0) begin
                                next_state <= STATE_2;
                            end
                        end
                    end
                end
                
                STATE_0: begin
                    result_valid <= 1'b1;
                    result <= 8'd0;
                    result_index <= index;
                    count_0 <= count_0 - 16'd1;
                    index <= index + 16'd1;
                    
                    // Transition to STATE_1 if possible
                    if (count_1 > 16'd0) begin
                        next_state <= STATE_1;
                    end else if (count_0 == 16'd0 && count_1 == 16'd0 && count_2 == 16'd0 && count_3 == 16'd0) begin
                        next_state <= IDLE;
                        done <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                        impossible <= 1'b1;
                    end
                end
                
                STATE_1: begin
                    result_valid <= 1'b1;
                    result <= 8'd1;
                    result_index <= index;
                    count_1 <= count_1 - 16'd1;
                    index <= index + 16'd1;
                    
                    // Prefer direction with higher count
                    if ((count_0 >= count_2) && count_0 > 16'd0) begin
                        next_state <= STATE_0;
                    end else if ((count_2 > count_0) && count_2 > 16'd0) begin
                        next_state <= STATE_2;
                    end else if (count_0 > 16'd0) begin
                        next_state <= STATE_0;
                    end else if (count_2 > 16'd0) begin
                        next_state <= STATE_2;
                    end else if (count_0 == 16'd0 && count_1 == 16'd0 && count_2 == 16'd0 && count_3 == 16'd0) begin
                        next_state <= IDLE;
                        done <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                        impossible <= 1'b1;
                    end
                end
                
                STATE_2: begin
                    result_valid <= 1'b1;
                    result <= 8'd2;
                    result_index <= index;
                    count_2 <= count_2 - 16'd1;
                    index <= index + 16'd1;
                    
                    // Prefer direction with higher count
                    if ((count_1 >= count_3) && count_1 > 16'd0) begin
                        next_state <= STATE_1;
                    end else if ((count_3 > count_1) && count_3 > 16'd0) begin
                        next_state <= STATE_3;
                    end else if (count_1 > 16'd0) begin
                        next_state <= STATE_1;
                    end else if (count_3 > 16'd0) begin
                        next_state <= STATE_3;
                    end else if (count_0 == 16'd0 && count_1 == 16'd0 && count_2 == 16'd0 && count_3 == 16'd0) begin
                        next_state <= IDLE;
                        done <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                        impossible <= 1'b1;
                    end
                end
                
                STATE_3: begin
                    result_valid <= 1'b1;
                    result <= 8'd3;
                    result_index <= index;
                    count_3 <= count_3 - 16'd1;
                    index <= index + 16'd1;
                    
                    // Transition to STATE_2 if possible
                    if (count_2 > 16'd0) begin
                        next_state <= STATE_2;
                    end else if (count_0 == 16'd0 && count_1 == 16'd0 && count_2 == 16'd0 && count_3 == 16'd0) begin
                        next_state <= IDLE;
                        done <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                        impossible <= 1'b1;
                    end
                end
                
                default: begin
                    next_state <= IDLE;
                    result_valid <= 1'b0;
                end
            endcase
            
            // Cycle counter to prevent infinite loops
            cycle_count <= cycle_count + 16'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                impossible <= 1'b1;
            end
        end
    end

endmodule