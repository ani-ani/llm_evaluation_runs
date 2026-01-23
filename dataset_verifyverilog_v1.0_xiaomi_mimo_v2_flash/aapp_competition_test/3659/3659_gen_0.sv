module bookcase_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] book_count,
    
    input wire [8:0] h0, h1, h2, h3, h4, h5, h6, h7,
    input wire [5:0] t0, t1, t2, t3, t4, t5, t6, t7,
    
    output reg [19:0] min_area,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE = 3'd3;
    
    reg [2:0] state;
    reg [15:0] iter;
    reg [19:0] best;
    reg [19:0] current_area;
    
    // Internal storage for books
    reg [8:0] height [0:7];
    reg [5:0] thickness [0:7];
    
    // Combinational shelf calculation
    reg [1:0] shelf0, shelf1, shelf2, shelf3, shelf4, shelf5, shelf6, shelf7;
    reg [8:0] max_h0, max_h1, max_h2;
    reg [7:0] sum_t0, sum_t1, sum_t2;
    
    integer i;
    
    always @(*) begin
        // Calculate shelf assignments for current iteration
        shelf0 = iter % 3;
        shelf1 = (iter / 3) % 3;
        shelf2 = (iter / 9) % 3;
        shelf3 = (iter / 27) % 3;
        shelf4 = (iter / 81) % 3;
        shelf5 = (iter / 243) % 3;
        shelf6 = (iter / 729) % 3;
        shelf7 = (iter / 2187) % 3;
        
        // Reset counters
        max_h0 = 9'd0;
        max_h1 = 9'd0;
        max_h2 = 9'd0;
        sum_t0 = 8'd0;
        sum_t1 = 8'd0;
        sum_t2 = 8'd0;
        
        // Process books
        for (i = 0; i < 8; i = i + 1) begin
            if (i < book_count) begin
                case (i)
                    0: begin
                        case (shelf0)
                            2'd0: begin
                                if (height[0] > max_h0) max_h0 = height[0];
                                sum_t0 = sum_t0 + thickness[0];
                            end
                            2'd1: begin
                                if (height[0] > max_h1) max_h1 = height[0];
                                sum_t1 = sum_t1 + thickness[0];
                            end
                            default: begin
                                if (height[0] > max_h2) max_h2 = height[0];
                                sum_t2 = sum_t2 + thickness[0];
                            end
                        endcase
                    end
                    1: begin
                        case (shelf1)
                            2'd0: begin
                                if (height[1] > max_h0) max_h0 = height[1];
                                sum_t0 = sum_t0 + thickness[1];
                            end
                            2'd1: begin
                                if (height[1] > max_h1) max_h1 = height[1];
                                sum_t1 = sum_t1 + thickness[1];
                            end
                            default: begin
                                if (height[1] > max_h2) max_h2 = height[1];
                                sum_t2 = sum_t2 + thickness[1];
                            end
                        endcase
                    end
                    2: begin
                        case (shelf2)
                            2'd0: begin
                                if (height[2] > max_h0) max_h0 = height[2];
                                sum_t0 = sum_t0 + thickness[2];
                            end
                            2'd1: begin
                                if (height[2] > max_h1) max_h1 = height[2];
                                sum_t1 = sum_t1 + thickness[2];
                            end
                            default: begin
                                if (height[2] > max_h2) max_h2 = height[2];
                                sum_t2 = sum_t2 + thickness[2];
                            end
                        endcase
                    end
                    3: begin
                        case (shelf3)
                            2'd0: begin
                                if (height[3] > max_h0) max_h0 = height[3];
                                sum_t0 = sum_t0 + thickness[3];
                            end
                            2'd1: begin
                                if (height[3] > max_h1) max_h1 = height[3];
                                sum_t1 = sum_t1 + thickness[3];
                            end
                            default: begin
                                if (height[3] > max_h2) max_h2 = height[3];
                                sum_t2 = sum_t2 + thickness[3];
                            end
                        endcase
                    end
                    4: begin
                        case (shelf4)
                            2'd0: begin
                                if (height[4] > max_h0) max_h0 = height[4];
                                sum_t0 = sum_t0 + thickness[4];
                            end
                            2'd1: begin
                                if (height[4] > max_h1) max_h1 = height[4];
                                sum_t1 = sum_t1 + thickness[4];
                            end
                            default: begin
                                if (height[4] > max_h2) max_h2 = height[4];
                                sum_t2 = sum_t2 + thickness[4];
                            end
                        endcase
                    end
                    5: begin
                        case (shelf5)
                            2'd0: begin
                                if (height[5] > max_h0) max_h0 = height[5];
                                sum_t0 = sum_t0 + thickness[5];
                            end
                            2'd1: begin
                                if (height[5] > max_h1) max_h1 = height[5];
                                sum_t1 = sum_t1 + thickness[5];
                            end
                            default: begin
                                if (height[5] > max_h2) max_h2 = height[5];
                                sum_t2 = sum_t2 + thickness[5];
                            end
                        endcase
                    end
                    6: begin
                        case (shelf6)
                            2'd0: begin
                                if (height[6] > max_h0) max_h0 = height[6];
                                sum_t0 = sum_t0 + thickness[6];
                            end
                            2'd1: begin
                                if (height[6] > max_h1) max_h1 = height[6];
                                sum_t1 = sum_t1 + thickness[6];
                            end
                            default: begin
                                if (height[6] > max_h2) max_h2 = height[6];
                                sum_t2 = sum_t2 + thickness[6];
                            end
                        endcase
                    end
                    7: begin
                        case (shelf7)
                            2'd0: begin
                                if (height[7] > max_h0) max_h0 = height[7];
                                sum_t0 = sum_t0 + thickness[7];
                            end
                            2'd1: begin
                                if (height[7] > max_h1) max_h1 = height[7];
                                sum_t1 = sum_t1 + thickness[7];
                            end
                            default: begin
                                if (height[7] > max_h2) max_h2 = height[7];
                                sum_t2 = sum_t2 + thickness[7];
                            end
                        endcase
                    end
                endcase
            end
        end
        
        // Calculate area: (max_h0 + max_h1 + max_h2) * max(sum_t0, sum_t1, sum_t2)
        if (sum_t0 > sum_t1) begin
            if (sum_t0 > sum_t2) begin
                current_area = (max_h0 + max_h1 + max_h2) * {12'd0, sum_t0};
            end else begin
                current_area = (max_h0 + max_h1 + max_h2) * {12'd0, sum_t2};
            end
        end else begin
            if (sum_t1 > sum_t2) begin
                current_area = (max_h0 + max_h1 + max_h2) * {12'd0, sum_t1};
            end else begin
                current_area = (max_h0 + max_h1 + max_h2) * {12'd0, sum_t2};
            end
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_area <= 20'd0;
            iter <= 16'd0;
            best <= 20'hFFFFF;
            for (i = 0; i < 8; i = i + 1) begin
                height[i] <= 9'd0;
                thickness[i] <= 6'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    height[0] <= h0; thickness[0] <= t0;
                    height[1] <= h1; thickness[1] <= t1;
                    height[2] <= h2; thickness[2] <= t2;
                    height[3] <= h3; thickness[3] <= t3;
                    height[4] <= h4; thickness[4] <= t4;
                    height[5] <= h5; thickness[5] <= t5;
                    height[6] <= h6; thickness[6] <= t6;
                    height[7] <= h7; thickness[7] <= t7;
                    
                    iter <= 16'd0;
                    best <= 20'hFFFFF;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (iter < 16'd6561) begin
                        if (iter > 0 && current_area < best) begin
                            best <= current_area;
                        end
                        iter <= iter + 16'd1;
                    end else begin
                        min_area <= best;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule