module rain_cycler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] c,
    input wire [23:0] d,
    input wire [7:0] rain [0:15],
    output reg [23:0] result,
    output reg done
);

    // Parameters
    localparam T = 16;
    localparam DATA_WIDTH = 24;
    localparam RAIN_WIDTH = 8;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_RAIN_CUM = 2'd1;
    localparam [1:0] COMPUTE_MIN = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] dt;
    reg [3:0] i;
    reg [23:0] rain_cum [0:15];
    reg [23:0] min_wetness;
    reg [23:0] current_wetness;
    reg [23:0] sweat;
    reg [23:0] rain_wetness;
    reg [23:0] temp_product;
    reg [23:0] temp_dividend;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            dt <= 4'd0;
            i <= 4'd0;
            min_wetness <= 24'd0;
            current_wetness <= 24'd0;
            sweat <= 24'd0;
            rain_wetness <= 24'd0;
            temp_product <= 24'd0;
            temp_dividend <= 24'd0;
            done <= 1'b0;
            result <= 24'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                rain_cum[i] <= 24'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_RAIN_CUM;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_RAIN_CUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i == 0) begin
                        rain_cum[0] <= 24'd0;
                        i <= i + 4'd1;
                    end else if (i < T) begin
                        rain_cum[i] <= rain_cum[i-1] + rain[i-1];
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        next_state <= COMPUTE_MIN;
                    end
                end

                COMPUTE_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (dt == 0) begin
                        dt <= dt + 4'd1;
                    end else if (dt < T) begin
                        // Compute rain wetness
                        rain_wetness <= rain_cum[dt] - rain_cum[0];

                        // Compute sweat: c * (60*d)^2 / dt
                        // First compute (60*d)
                        temp_product <= 60 * d;
                        // Then compute (60*d)^2
                        temp_product <= temp_product * temp_product;
                        // Then multiply by c
                        temp_dividend <= c * temp_product;
                        // Then divide by dt
                        sweat <= temp_dividend / dt;

                        // Total wetness
                        current_wetness <= rain_wetness + sweat;

                        // Track minimum
                        if (dt == 1) begin
                            min_wetness <= current_wetness;
                        end else if (current_wetness < min_wetness) begin
                            min_wetness <= current_wetness;
                        end

                        dt <= dt + 4'd1;
                    end else begin
                        dt <= 4'd0;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= min_wetness;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
endmodule