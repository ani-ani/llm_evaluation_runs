module GarbageDisposal (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] k,
    input [7:0] a_0,
    input [7:0] a_1,
    input [7:0] a_2,
    input [7:0] a_3,
    input [7:0] a_4,
    input [7:0] a_5,
    input [7:0] a_6,
    input [7:0] a_7,
    output reg [15:0] bags,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] day;
    reg [7:0] leftover;
    reg [7:0] a_current;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Current day's garbage value
    always @(*) begin
        case (day)
            8'd0: a_current = a_0;
            8'd1: a_current = a_1;
            8'd2: a_current = a_2;
            8'd3: a_current = a_3;
            8'd4: a_current = a_4;
            8'd5: a_current = a_5;
            8'd6: a_current = a_6;
            8'd7: a_current = a_7;
            default: a_current = 8'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bags <= 16'd0;
            done <= 1'b0;
            day <= 8'd0;
            leftover <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    bags <= 16'd0;
                    leftover <= 8'd0;
                    day <= 8'd0;
                    if (start && n != 8'd0) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (day < n) begin
                        // Compute bags for leftover: ceil(last/k)
                        if (leftover > 8'd0) begin
                            // ceil(leftover/k) = (leftover + k - 1) / k
                            bags <= bags + (16'd0 + {8'd0, leftover} + {8'd0, k} - 16'd1) / k;
                            leftover <= 8'd0;
                        end
                        
                        // Use remaining space for today's garbage
                        // Need to wait for previous computation to complete
                        // Use next cycle for day increment and leftover calc
                        if (cycle_count[0] == 1'd0) begin
                            // First half of processing day: wait for bag computation
                            // Do nothing, just proceed
                        end else begin
                            // Second half: add today's garbage
                            if (a_current > 8'd0) begin
                                leftover <= a_current;
                            end
                            day <= day + 8'd1;
                        end
                        
                        // Check completion
                        if ((day == n - 8'd1) && (cycle_count[0] == 1'd1) && (a_current == 8'd0)) begin
                            // Last day and no garbage
                            if (leftover == 8'd0) begin
                                state <= DONE_STATE;
                            end
                        end
                        
                        // After last day processing
                        if (day == n && cycle_count[0] == 1'd1) begin
                            if (leftover == 8'd0) begin
                                state <= DONE_STATE;
                            end
                        end
                    end
                    
                    // After last day, dispose remaining leftover
                    if (day == n && leftover > 8'd0 && cycle_count[0] == 1'd0) begin
                        bags <= bags + (16'd0 + {8'd0, leftover} + {8'd0, k} - 16'd1) / k;
                        leftover <= 8'd0;
                    end
                    
                    if (day == n && leftover == 8'd0 && cycle_count[0] == 1'd1) begin
                        state <= DONE_STATE;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule