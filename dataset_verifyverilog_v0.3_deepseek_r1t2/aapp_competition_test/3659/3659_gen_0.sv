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

    // Internal memory
    reg [8:0] height [0:7];
    reg [5:0] thickness [0:7];

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [15:0] iter;
    reg [19:0] best;
    reg [19:0] current_area;

    // Iteration limit (3^8 = 6561)
    localparam [15:0] MAX_ITER = 16'd6561;

    // Shelf calculations
    reg [8:0] max_h0, max_h1, max_h2;
    reg [7:0] sum_t0, sum_t1, sum_t2;
    reg [7:0] max_width;

    // Function to get shelf assignment
    function [1:0] get_shelf(input [15:0] cnt, input [3:0] idx);
        integer i;
        reg [15:0] temp;
        begin
            temp = cnt;
            for (i = 0; i < 8; i = i + 1) begin
                if (i < idx) temp = temp / 3;
            end
            get_shelf = temp % 3;
        end
    endfunction

    // Combinational area calculation
    always @(*) begin
        // Initialize shelf values
        max_h0 = 9'd0;
        max_h1 = 9'd0;
        max_h2 = 9'd0;
        sum_t0 = 8'd0;
        sum_t1 = 8'd0;
        sum_t2 = 8'd0;
        
        // Process each book
        for (integer i = 0; i < 8; i = i + 1) begin
            if (i < book_count) begin
                case (get_shelf(iter, i))
                    2'd0: begin
                        if (height[i] > max_h0) max_h0 = height[i];
                        sum_t0 = sum_t0 + {2'b0, thickness[i]};
                    end
                    2'd1: begin
                        if (height[i] > max_h1) max_h1 = height[i];
                        sum_t1 = sum_t1 + {2'b0, thickness[i]};
                    end
                    2'd2: begin
                        if (height[i] > max_h2) max_h2 = height[i];
                        sum_t2 = sum_t2 + {2'b0, thickness[i]};
                    end
                endcase
            end
        end
        
        // Find max width
        max_width = (sum_t0 > sum_t1) ? 
                   ((sum_t0 > sum_t2) ? sum_t0 : sum_t2) :
                   ((sum_t1 > sum_t2) ? sum_t1 : sum_t2);
        
        // Total height * max width
        current_area = (max_h0 + max_h1 + max_h2) * max_width;
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_area <= 20'd0;
            iter <= 16'd0;
            best <= 20'hFFFFF;
            // Initialize arrays
            for (integer j = 0; j < 8; j = j + 1) begin
                height[j] <= 9'd0;
                thickness[j] <= 6'd0;
            end
        end
        else begin
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
                    if (iter < MAX_ITER) begin
                        // Update best result
                        if ((current_area < best) || (iter == 16'd0)) begin
                            best <= current_area;
                        end
                        iter <= iter + 16'd1;
                    end
                    else begin
                        min_area <= best;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule