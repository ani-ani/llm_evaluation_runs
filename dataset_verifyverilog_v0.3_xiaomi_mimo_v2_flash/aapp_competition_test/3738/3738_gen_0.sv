module robot_reach (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char,
    input wire char_valid,
    input wire [6:0] len,
    input wire signed [31:0] a,
    input wire signed [31:0] b,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RECEIVE = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [6:0] count;
    reg signed [31:0] current_x, current_y;
    reg signed [31:0] dx, dy;
    reg [6:0] index;
    reg signed [31:0] x_mem [0:100];
    reg signed [31:0] y_mem [0:100];
    
    // Helper registers for calculations
    reg signed [31:0] ax_reg, by_reg;
    reg signed [63:0] prod1_reg, prod2_reg;
    reg sign_ok_dx_reg, sign_ok_dy_reg;
    reg [6:0] len_plus_one;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            count <= 7'd0;
            index <= 7'd0;
            current_x <= 32'sd0;
            current_y <= 32'sd0;
            dx <= 32'sd0;
            dy <= 32'sd0;
            ax_reg <= 32'sd0;
            by_reg <= 32'sd0;
            prod1_reg <= 64'sd0;
            prod2_reg <= 64'sd0;
            sign_ok_dx_reg <= 1'b0;
            sign_ok_dy_reg <= 1'b0;
            len_plus_one <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= RECEIVE;
                        count <= 7'd0;
                        current_x <= 32'sd0;
                        current_y <= 32'sd0;
                        x_mem[0] <= 32'sd0;
                        y_mem[0] <= 32'sd0;
                        done <= 1'b0;
                        result <= 1'b0;
                        len_plus_one <= len + 7'd1;
                    end
                end

                RECEIVE: begin
                    if (char_valid) begin
                        // Update current position
                        case (char)
                            8'd85, 8'd117: current_y <= current_y + 32'sd1;  // 'U', 'u'
                            8'd68, 8'd100: current_y <= current_y - 32'sd1;  // 'D', 'd'
                            8'd76, 8'd108: current_x <= current_x - 32'sd1;  // 'L', 'l'
                            8'd82, 8'd114: current_x <= current_x + 32'sd1;  // 'R', 'r'
                            default: ; // Ignore invalid
                        endcase
                        
                        // Store new position
                        if (char == 8'd76 || char == 8'd108) begin
                            x_mem[count + 7'd1] <= current_x - 32'sd1;
                        end else if (char == 8'd82 || char == 8'd114) begin
                            x_mem[count + 7'd1] <= current_x + 32'sd1;
                        end else begin
                            x_mem[count + 7'd1] <= current_x;
                        end
                        
                        if (char == 8'd85 || char == 8'd117) begin
                            y_mem[count + 7'd1] <= current_y + 32'sd1;
                        end else if (char == 8'd68 || char == 8'd100) begin
                            y_mem[count + 7'd1] <= current_y - 32'sd1;
                        end else begin
                            y_mem[count + 7'd1] <= current_y;
                        end
                        
                        count <= count + 7'd1;
                        
                        if (count + 7'd1 == len) begin
                            if (char == 8'd76 || char == 8'd108) begin
                                dx <= current_x - 32'sd1;
                            end else if (char == 8'd82 || char == 8'd114) begin
                                dx <= current_x + 32'sd1;
                            end else begin
                                dx <= current_x;
                            end
                            
                            if (char == 8'd85 || char == 8'd117) begin
                                dy <= current_y + 32'sd1;
                            end else if (char == 8'd68 || char == 8'd100) begin
                                dy <= current_y - 32'sd1;
                            end else begin
                                dy <= current_y;
                            end
                            
                            state <= CHECK;
                            index <= 7'd0;
                        end
                    end
                end

                CHECK: begin
                    if (index <= len) begin
                        // Calculate helper values
                        ax_reg <= a - x_mem[index];
                        by_reg <= b - y_mem[index];
                        
                        prod1_reg <= (a - x_mem[index]) * dy;
                        prod2_reg <= (b - y_mem[index]) * dx;
                        
                        if (dx > 32'sd0) begin
                            sign_ok_dx_reg <= ((a - x_mem[index]) >= 32'sd0) ? 1'b1 : 1'b0;
                        end else if (dx < 32'sd0) begin
                            sign_ok_dx_reg <= ((a - x_mem[index]) <= 32'sd0) ? 1'b1 : 1'b0;
                        end else begin
                            sign_ok_dx_reg <= 1'b1;
                        end
                        
                        if (dy > 32'sd0) begin
                            sign_ok_dy_reg <= ((b - y_mem[index]) >= 32'sd0) ? 1'b1 : 1'b0;
                        end else if (dy < 32'sd0) begin
                            sign_ok_dy_reg <= ((b - y_mem[index]) <= 32'sd0) ? 1'b1 : 1'b0;
                        end else begin
                            sign_ok_dy_reg <= 1'b1;
                        end
                        
                        // Check conditions for next cycle
                        if (dx == 32'sd0 && dy == 32'sd0) begin
                            if (a == x_mem[index] && b == y_mem[index]) begin
                                result <= 1'b1;
                                state <= FINISHED;
                            end else if (index == len) begin
                                result <= 1'b0;
                                state <= FINISHED;
                            end else begin
                                index <= index + 7'd1;
                            end
                        end else if (dx == 32'sd0) begin
                            if (a == x_mem[index]) begin
                                if (b == y_mem[index]) begin
                                    result <= 1'b1;
                                    state <= FINISHED;
                                end else if (dy != 32'sd0 && ((b - y_mem[index]) % dy) == 32'sd0) begin
                                    integer k;
                                    k = (b - y_mem[index]) / dy;
                                    if (k >= 32'sd0) begin
                                        result <= 1'b1;
                                        state <= FINISHED;
                                    end else if (index == len) begin
                                        result <= 1'b0;
                                        state <= FINISHED;
                                    end else begin
                                        index <= index + 7'd1;
                                    end
                                end else if (index == len) begin
                                    result <= 1'b0;
                                    state <= FINISHED;
                                end else begin
                                    index <= index + 7'd1;
                                end
                            end else if (index == len) begin
                                result <= 1'b0;
                                state <= FINISHED;
                            end else begin
                                index <= index + 7'd1;
                            end
                        end else if (dy == 32'sd0) begin
                            if (b == y_mem[index]) begin
                                if (a == x_mem[index]) begin
                                    result <= 1'b1;
                                    state <= FINISHED;
                                end else if (dx != 32'sd0 && ((a - x_mem[index]) % dx) == 32'sd0) begin
                                    integer k;
                                    k = (a - x_mem[index]) / dx;
                                    if (k >= 32'sd0) begin
                                        result <= 1'b1;
                                        state <= FINISHED;
                                    end else if (index == len) begin
                                        result <= 1'b0;
                                        state <= FINISHED;
                                    end else begin
                                        index <= index + 7'd1;
                                    end
                                end else if (index == len) begin
                                    result <= 1'b0;
                                    state <= FINISHED;
                                end else begin
                                    index <= index + 7'd1;
                                end
                            end else if (index == len) begin
                                result <= 1'b0;
                                state <= FINISHED;
                            end else begin
                                index <= index + 7'd1;
                            end
                        end else begin
                            // Both dx and dy non-zero
                            if (prod1_reg == prod2_reg && sign_ok_dx_reg && sign_ok_dy_reg) begin
                                result <= 1'b1;
                                state <= FINISHED;
                            end else if (index == len) begin
                                result <= 1'b0;
                                state <= FINISHED;
                            end else begin
                                index <= index + 7'd1;
                            end
                        end
                    end else begin
                        result <= 1'b0;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule