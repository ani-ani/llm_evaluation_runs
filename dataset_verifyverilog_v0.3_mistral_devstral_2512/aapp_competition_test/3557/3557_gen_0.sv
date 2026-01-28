module chaos_calculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    input [7:0] p4,
    input [7:0] p5,
    input [7:0] p6,
    input [7:0] p7,
    input [3:0] d0,
    input [3:0] d1,
    input [3:0] d2,
    input [3:0] d3,
    input [3:0] d4,
    input [3:0] d5,
    input [3:0] d6,
    input [3:0] d7,
    output reg [15:0] max_chaos,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] step_count;
    reg [3:0] active_coaches;
    reg [7:0] current_p[0:7];
    reg [3:0] destruction_order[0:7];
    reg [15:0] current_max_chaos;
    reg [15:0] total_chaos;
    reg [3:0] num_segments;
    reg [3:0] i, j;
    reg [15:0] segment_sum;
    reg [15:0] segment_chaos;
    reg [15:0] temp_chaos;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 4'd0;
            active_coaches <= 4'd0;
            current_max_chaos <= 16'd0;
            max_chaos <= 16'd0;
            done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                current_p[i] <= 8'd0;
                destruction_order[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = PROCESS;
            end
            
            PROCESS: begin
                if (step_count == n - 4'd1) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Load passenger counts
                    current_p[0] <= p0;
                    current_p[1] <= p1;
                    current_p[2] <= p2;
                    current_p[3] <= p3;
                    current_p[4] <= p4;
                    current_p[5] <= p5;
                    current_p[6] <= p6;
                    current_p[7] <= p7;
                    
                    // Load destruction order
                    destruction_order[0] <= d0;
                    destruction_order[1] <= d1;
                    destruction_order[2] <= d2;
                    destruction_order[3] <= d3;
                    destruction_order[4] <= d4;
                    destruction_order[5] <= d5;
                    destruction_order[6] <= d6;
                    destruction_order[7] <= d7;
                    
                    step_count <= 4'd0;
                    active_coaches <= 4'd0;
                    current_max_chaos <= 16'd0;
                end
                
                PROCESS: begin
                    // Activate next coach in reverse order
                    active_coaches <= active_coaches | (1 << (destruction_order[n - 4'd1 - step_count] - 4'd1));
                    
                    // Compute segments and chaos
                    total_chaos <= 16'd0;
                    num_segments <= 4'd0;
                    
                    // Segment detection
                    for (i = 0; i < 8; i = i + 1) begin
                        if (active_coaches[i]) begin
                            segment_sum <= current_p[i];
                            j = i + 1;
                            while (j < 8 && active_coaches[j]) begin
                                segment_sum <= segment_sum + current_p[j];
                                j = j + 1;
                            end
                            
                            // Calculate chaos: ((sum + 9) / 10) * 10
                            segment_chaos <= (segment_sum + 16'd9) / 16'd10;
                            segment_chaos <= segment_chaos * 16'd10;
                            
                            total_chaos <= total_chaos + segment_chaos;
                            num_segments <= num_segments + 4'd1;
                            i = j - 1;
                        end
                    end
                    
                    // Update max chaos
                    temp_chaos <= total_chaos * num_segments;
                    if (temp_chaos > current_max_chaos) begin
                        current_max_chaos <= temp_chaos;
                    end
                    
                    step_count <= step_count + 4'd1;
                end
                
                FINISH: begin
                    max_chaos <= current_max_chaos;
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule