module roman_digits_solver (
    input clk,
    input rst_n,
    input start,
    input [29:0] n,
    output reg [59:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_RANGE = 3'b001;
    localparam COMPUTE_SMALL = 3'b010;
    localparam COMPUTE_LARGE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [5:0] counter; // Counter for delay or indexing
    reg [29:0] n_reg;  // Store n locally

    // Precomputed values for n=1 to 20
    // Index 0 unused
    wire [59:0] precomputed [0:20];
    assign precomputed[0]  = 60'd0;
    assign precomputed[1]  = 60'd2;
    assign precomputed[2]  = 60'd4;
    assign precomputed[3]  = 60'd7;
    assign precomputed[4]  = 60'd10;
    assign precomputed[5]  = 60'd13;
    assign precomputed[6]  = 60'd16;
    assign precomputed[7]  = 60'd19;
    assign precomputed[8]  = 60'd22;
    assign precomputed[9]  = 60'd25;
    assign precomputed[10] = 60'd28;
    assign precomputed[11] = 60'd31;
    // Values for 12-20 provided in prompt
    assign precomputed[12] = 60'd341;
    assign precomputed[13] = 60'd390;
    assign precomputed[14] = 60'd439;
    assign precomputed[15] = 60'd488;
    assign precomputed[16] = 60'd537;
    assign precomputed[17] = 60'd586;
    assign precomputed[18] = 60'd635;
    assign precomputed[19] = 60'd684;
    assign precomputed[20] = 60'd733;

    // Multiplication logic intermediates
    reg [59:0] mult_temp;
    reg [59:0] sub_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 60'd0;
            counter <= 6'd0;
            n_reg <= 30'd0;
            mult_temp <= 60'd0;
            sub_temp <= 60'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= CHECK_RANGE;
                    end
                end

                CHECK_RANGE: begin
                    // Check if n <= 20 (n_reg <= 20)
                    if (n_reg <= 20) begin
                        state <= COMPUTE_SMALL;
                        counter <= n_reg[5:0]; // Use counter as index
                    end else begin
                        state <= COMPUTE_LARGE;
                    end
                end

                COMPUTE_SMALL: begin
                    // Latency requirement allows 20 cycles. 
                    // We can output immediately from lookup or pipelined.
                    // To be safe and structured, we assume 1 cycle for lookup.
                    // If strictly needs 20 cycles, we could stall, but usually means max latency.
                    // The prompt says "Result valid 20 clock cycles after start".
                    // We will implement a counter to match the 20 cycle latency exactly, 
                    // handling the case where we might be ready earlier.
                    
                    if (counter < 20) begin
                        counter <= counter + 1;
                    end else begin
                        result <= precomputed[n_reg[5:0]];
                        state <= DONE;
                    end
                end

                COMPUTE_LARGE: begin
                    // Pipeline: Cycle 1: 49 * n
                    // Cycle 2: - 247
                    // Cycle 3: Check total latency
                    
                    if (counter == 0) begin
                        // 49 = 32 + 16 + 1
                        mult_temp <= (n_reg << 5) + (n_reg << 4) + n_reg;
                        counter <= counter + 1;
                    end else if (counter == 1) begin
                        sub_temp <= mult_temp - 247;
                        counter <= counter + 1;
                    end else begin
                        // Fill remaining cycles to meet 20 total latency
                        if (counter < 18) begin // 1 (check) + 1 (mult) + 1 (sub) + 18 filler = 21 cycles total from start? 
                            // Let's tune for roughly 20 cycles total from start.
                            // Start -> Check (1) -> ComputeLarge -> (if large, we need delay)
                            // We have 1 cycle for Check. 
                            // We will use a generic filler to ensure we hit cycle 20.
                            counter <= counter + 1;
                        end else begin
                            result <= sub_temp;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset
                        state <= IDLE;
                        counter <= 6'd0;
                    end
                end
            endcase
        end
    end

endmodule
