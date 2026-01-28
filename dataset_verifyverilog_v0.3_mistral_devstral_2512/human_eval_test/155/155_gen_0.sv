module even_odd_count(
    input clk,
    input rst_n,
    input start,
    input signed [31:0] num,
    output reg [3:0] even_count,
    output reg [3:0] odd_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg signed [31:0] current_num;
    reg [3:0] even_count_reg;
    reg [3:0] odd_count_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_num <= 32'd0;
            even_count_reg <= 4'd0;
            odd_count_reg <= 4'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
            even_count <= 4'd0;
            odd_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= PROCESSING;
                        current_num <= num;
                        even_count_reg <= 4'd0;
                        odd_count_reg <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (current_num == 32'd0) begin
                        next_state <= DONE_STATE;
                    end else begin
                        // Take absolute value
                        reg signed [31:0] abs_num;
                        if (current_num[31]) begin
                            abs_num <= -current_num;
                        end else begin
                            abs_num <= current_num;
                        end

                        // Extract last digit
                        reg [3:0] digit;
                        digit <= abs_num % 10;

                        // Check if even
                        if (digit % 2 == 0) begin
                            even_count_reg <= even_count_reg + 4'd1;
                        end else begin
                            odd_count_reg <= odd_count_reg + 4'd1;
                        end

                        // Divide by 10
                        current_num <= abs_num / 10;
                        next_state <= PROCESSING;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    even_count <= even_count_reg;
                    odd_count <= odd_count_reg;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule