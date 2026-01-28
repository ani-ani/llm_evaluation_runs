module cube_volume (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] side,
    output reg [23:0] volume,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] side_reg;
    reg [15:0] intermediate;  // side * side (max: 255*255 = 65025, fits in 16 bits)
    reg [23:0] next_volume;
    reg next_done;
    reg [2:0] counter;  // Pipeline stage counter (max 3 stages)

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC;
                end else begin
                    next_state = IDLE;
                end
            end
            CALC: begin
                if (counter >= 3'd3) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            volume <= 24'd0;
            done <= 1'b0;
            side_reg <= 8'd0;
            intermediate <= 16'd0;
            counter <= 3'd0;
        end else begin
            state <= next_state;
            done <= next_done;
            volume <= next_volume;

            case (state)
                IDLE: begin
                    if (start) begin
                        side_reg <= side;
                        counter <= 3'd0;
                    end
                end
                CALC: begin
                    counter <= counter + 3'd1;
                    if (counter == 3'd0) begin
                        // Stage 1: Compute side * side
                        intermediate <= side_reg * side_reg;
                    end else if (counter == 3'd1) begin
                        // Stage 2: Hold intermediate value
                        intermediate <= intermediate;
                    end else if (counter == 3'd2) begin
                        // Stage 3: Compute intermediate * side (result ready next cycle)
                        // No register update needed for final multiplication
                    end
                end
                FINISH: begin
                    // Reset counter
                    counter <= 3'd0;
                end
            endcase
        end
    end

    // Output logic
    always @(*) begin
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_volume = volume;  // Keep previous value
            end
            CALC: begin
                next_done = 1'b0;
                next_volume = volume;  // Keep previous value
            end
            FINISH: begin
                next_done = 1'b1;
                // Compute final result in combinational logic
                next_volume = intermediate * side_reg;  // 16-bit * 8-bit = 24-bit
            end
            default: begin
                next_done = 1'b0;
                next_volume = volume;
            end
        endcase
    end

endmodule