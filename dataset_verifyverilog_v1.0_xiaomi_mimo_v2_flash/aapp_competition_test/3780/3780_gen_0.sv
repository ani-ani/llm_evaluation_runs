module resize_bilinear(
    input clk,
    input rst_n,
    input start,
    input [7:0] img_in [0:1023],
    input [9:0] src_width,
    input [9:0] src_height,
    input [9:0] dst_width,
    input [9:0] dst_height,
    output reg [7:0] img_out [0:1023],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Counter registers
    reg [9:0] row_counter;
    reg [9:0] col_counter;
    reg [9:0] out_counter;
    reg [9:0] max_rows;
    reg [9:0] max_cols;

    // Fixed-point coordinates (Q16.16)
    reg [31:0] src_x;
    reg [31:0] src_y;
    reg [31:0] src_x_frac;
    reg [31:0] src_y_frac;
    
    // Neighbor coordinates and weights
    reg [9:0] x0, x1, y0, y1;
    reg [15:0] w00, w01, w10, w11;  // Q8.8 fixed-point
    
    // Pixel values
    reg [7:0] p00, p01, p10, p11;
    reg [23:0] temp_sum;
    reg [7:0] interp_result;

    // Index calculation helper (combinational)
    function automatic [9:0] get_index;
        input [9:0] x, y, width;
        begin
            get_index = y * width + x;
        end
    endfunction

    // Initialize all registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            row_counter <= 10'd0;
            col_counter <= 10'd0;
            out_counter <= 10'd0;
            max_rows <= 10'd0;
            max_cols <= 10'd0;
            src_x <= 32'd0;
            src_y <= 32'd0;
            src_x_frac <= 32'd0;
            src_y_frac <= 32'd0;
            x0 <= 10'd0;
            x1 <= 10'd0;
            y0 <= 10'd0;
            y1 <= 10'd0;
            w00 <= 16'd0;
            w01 <= 16'd0;
            w10 <= 16'd0;
            w11 <= 16'd0;
            p00 <= 8'd0;
            p01 <= 8'd0;
            p10 <= 8'd0;
            p11 <= 8'd0;
            temp_sum <= 24'd0;
            interp_result <= 8'd0;
            // Initialize img_out array
            for (integer i = 0; i < 1024; i = i + 1) begin
                img_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    row_counter <= 10'd0;
                    col_counter <= 10'd0;
                    out_counter <= 10'd0;
                    max_rows <= dst_height - 10'd1;
                    max_cols <= dst_width - 10'd1;
                end
                
                LOAD: begin
                    // Calculate source coordinates with Q16.16 precision
                    src_x <= ({16'd0, col_counter} * {16'd0, src_width}) / dst_width;
                    src_y <= ({16'd0, row_counter} * {16'd0, src_height}) / dst_height;
                end
                
                CALC: begin
                    // Extract integer and fractional parts
                    x0 <= src_x[15:0];
                    x1 <= x0 + 10'd1;
                    y0 <= src_y[15:0];
                    y1 <= y0 + 10'd1;
                    
                    // Calculate weights (Q8.8 format: 1.0 = 256)
                    src_x_frac <= src_x[15:0] - {x0, 16'd0};
                    src_y_frac <= src_y[15:0] - {y0, 16'd0};
                    
                    w11 <= src_x_frac[23:16] * src_y_frac[23:16];
                    w10 <= (8'd256 - src_x_frac[23:16]) * src_y_frac[23:16];
                    w01 <= src_x_frac[23:16] * (8'd256 - src_y_frac[23:16]);
                    w00 <= (8'd256 - src_x_frac[23:16]) * (8'd256 - src_y_frac[23:16]);
                    
                    // Boundary checks
                    if (x1 >= src_width)
                        x1 <= src_width - 10'd1;
                    if (y1 >= src_height)
                        y1 <= src_height - 10'd1;
                    
                    // Load pixel values
                    p00 <= img_in[get_index(x0, y0, src_width)];
                    p01 <= img_in[get_index(x1, y0, src_width)];
                    p10 <= img_in[get_index(x0, y1, src_width)];
                    p11 <= img_in[get_index(x1, y1, src_width)];
                end
                
                OUTPUT: begin
                    // Bilinear interpolation
                    // Result = p00*w00 + p01*w01 + p10*w10 + p11*w11 (divide by 65536)
                    temp_sum <= (p00 * w00) + (p01 * w01) + (p10 * w10) + (p11 * w11);
                    
                    // Divide by 65536 (Q8.8 * Q8.8 = Q16.16, shift right 16 bits)
                    interp_result <= temp_sum[23:16];
                    
                    // Store result
                    img_out[out_counter] <= interp_result;
                    
                    // Update counters
                    if (col_counter < max_cols) begin
                        col_counter <= col_counter + 10'd1;
                    end else begin
                        col_counter <= 10'd0;
                        if (row_counter < max_rows) begin
                            row_counter <= row_counter + 10'd1;
                        end
                    end
                    
                    out_counter <= out_counter + 10'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                next_state = CALC;
            end
            
            CALC: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (out_counter >= (dst_width * dst_height))
                    next_state = FINISH;
                else
                    next_state = LOAD;
            end
            
            FINISH: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = FINISH;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule