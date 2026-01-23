module right_triangle_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] points [0:7],
    output reg [7:0] count,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam DONE = 3'b100;

    // Registers for Loop Control
    reg [2:0] state;
    reg [2:0] i, j, k;
    reg [1:0] check_state; // 0: check vertex i, 1: check vertex j, 2: check vertex k, 3: next triplet
    
    // Computation Registers
    reg signed [15:0] p1_x, p1_y;
    reg signed [15:0] p2_x, p2_y;
    reg signed [15:0] p3_x, p3_y;
    
    // Intermediate products for pipelining dot product calculation
    // Dot = (x2-x1)*(x3-x1) + (y2-y1)*(y3-y1)
    reg signed [31:0] dx1_dx2;
    reg signed [31:0] dy1_dy2;
    reg signed [31:0] dot_product;
    reg is_right_angle;

    // Next state logic and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            count <= 0;
            i <= 0; j <= 0; k <= 0;
            check_state <= 0;
            is_right_angle <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PROCESSING;
                        i <= 0; j <= 1; k <= 2;
                        check_state <= 0;
                        count <= 0;
                    end
                end

                PROCESSING: begin
                    case (check_state)
                        0: begin // Calculate for Vertex i (p1 as vertex)
                            // Load points
                            p1_x <= points[{i, 1'b0}];
                            p1_y <= points[{i, 1'b1}];
                            p2_x <= points[{j, 1'b0}];
                            p2_y <= points[{j, 1'b1}];
                            p3_x <= points[{k, 1'b0}];
                            p3_y <= points[{k, 1'b1}];
                            check_state <= 1;
                        end
                        
                        1: begin // Calculate dot product components
                            // Vector V1 = P2 - P1, Vector V2 = P3 - P1
                            dx1_dx2 <= (p2_x - p1_x) * (p3_x - p1_x);
                            dy1_dy2 <= (p2_y - p1_y) * (p3_y - p1_y);
                            check_state <= 2;
                        end

                        2: begin // Accumulate and Check
                            dot_product <= dx1_dx2 + dy1_dy2;
                            // We wait one more cycle for dot_product to settle if timing is tight,
                            // but usually this is combinational in the same cycle if logic depth allows.
                            // Let's assume combinational check for latency requirement.
                            // If synthesis fails, user should add a pipeline stage here.
                            if (dx1_dx2 + dy1_dy2 == 0) begin
                                count <= count + 1;
                                // Skip remaining checks for this triplet to save cycles
                                // Move to next triplet
                                if (k < 7) begin
                                    k <= k + 1;
                                    check_state <= 0;
                                end else if (j < 6) begin
                                    j <= j + 1;
                                    k <= j + 2; // k > j
                                    check_state <= 0;
                                end else if (i < 5) begin
                                    i <= i + 1;
                                    j <= i + 1;
                                    k <= i + 2;
                                    check_state <= 0;
                                end else begin
                                    state <= DONE;
                                end
                            end else begin
                                // Not right angle at P1, check P2
                                // Prepare for P2 check immediately in next cycle
                                check_state <= 3; // Transition to P2 setup state
                            end
                        end

                        3: begin // Setup for Vertex j
                            // P2 is the vertex (points index j)
                            // P1 and P3 are the other two points
                            p1_x <= points[{j, 1'b0}];
                            p1_y <= points[{j, 1'b1}];
                            p2_x <= points[{i, 1'b0}];
                            p2_y <= points[{i, 1'b1}];
                            p3_x <= points[{k, 1'b0}];
                            p3_y <= points[{k, 1'b1}];
                            check_state <= 4; // Go to calc for P2
                        end

                        4: begin // Calculate dot product for P2
                            dx1_dx2 <= (p2_x - p1_x) * (p3_x - p1_x);
                            dy1_dy2 <= (p2_y - p1_y) * (p3_y - p1_y);
                            check_state <= 5;
                        end

                        5: begin // Check P2
                            if (dx1_dx2 + dy1_dy2 == 0) begin
                                count <= count + 1;
                                // Next triplet
                                if (k < 7) begin
                                    k <= k + 1;
                                    check_state <= 0;
                                end else if (j < 6) begin
                                    j <= j + 1;
                                    k <= j + 2;
                                    check_state <= 0;
                                end else if (i < 5) begin
                                    i <= i + 1;
                                    j <= i + 1;
                                    k <= i + 2;
                                    check_state <= 0;
                                end else begin
                                    state <= DONE;
                                end
                            end else begin
                                // Not right angle at P2, check P3
                                check_state <= 6;
                            end
                        end

                        6: begin // Setup for Vertex k
                            // P3 is the vertex
                            p1_x <= points[{k, 1'b0}];
                            p1_y <= points[{k, 1'b1}];
                            p2_x <= points[{i, 1'b0}];
                            p2_y <= points[{i, 1'b1}];
                            p3_x <= points[{j, 1'b0}];
                            p3_y <= points[{j, 1'b1}];
                            check_state <= 7;
                        end

                        7: begin // Calculate dot product for P3
                            dx1_dx2 <= (p2_x - p1_x) * (p3_x - p1_x);
                            dy1_dy2 <= (p2_y - p1_y) * (p3_y - p1_y);
                            check_state <= 8;
                        end

                        8: begin // Check P3
                            if (dx1_dx2 + dy1_dy2 == 0) begin
                                count <= count + 1;
                            end
                            // Move to next triplet regardless of result (all 3 vertices checked)
                            if (k < 7) begin
                                k <= k + 1;
                                check_state <= 0;
                            end else if (j < 6) begin
                                j <= j + 1;
                                k <= j + 2;
                                check_state <= 0;
                            end else if (i < 5) begin
                                i <= i + 1;
                                j <= i + 1;
                                k <= i + 2;
                                check_state <= 0;
                            end else begin
                                state <= DONE;
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                    // Wait for reset or restart
                    // If start is asserted again (implicitly or explicitly), we should transition.
                    // Assuming user keeps start high until done, then lowers it, then asserts again.
                    // To make robust: if start is low, go back to IDLE? No, stay DONE until rst_n or start pulse.
                    // Let's stay in DONE until reset. If user wants to restart, they pulse start low then high.
                    // We can check if start is 0 to return to IDLE to allow restart.
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
