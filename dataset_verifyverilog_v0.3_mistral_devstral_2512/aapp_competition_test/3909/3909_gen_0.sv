module gerald_coins(
    input clk,
    input rst_n,
    input start,
    input [63:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] DIVIDE  = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    reg [63:0] current_n;
    reg [63:0] quotient;
    reg [1:0] remainder;
    reg divider_start;
    reg divider_done;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;

    // Divider module for division by 3
    divider_3 divider (
        .clk(clk),
        .rst_n(rst_n),
        .start(divider_start),
        .dividend(current_n),
        .quotient(quotient),
        .remainder(remainder),
        .done(divider_done)
    );

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            current_n <= 64'd0;
            divider_start <= 1'b0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = IDLE;
                end
            end
            DIVIDE: begin
                if (divider_done || cycle_count >= MAX_CYCLES) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = DIVIDE;
                end
            end
            COMPUTE: begin
                if (remainder == 0) begin
                    next_state = DIVIDE;
                end else begin
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
            current_n <= 64'd0;
            divider_start <= 1'b0;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                        divider_start <= 1'b1;
                        cycle_count <= 6'd0;
                    end
                end
                DIVIDE: begin
                    divider_start <= 1'b1;
                    cycle_count <= cycle_count + 6'd1;
                end
                COMPUTE: begin
                    if (remainder == 0) begin
                        current_n <= quotient;
                        divider_start <= 1'b1;
                        cycle_count <= 6'd0;
                    end else begin
                        result <= quotient + 64'd1;
                        done <= 1'b1;
                    end
                end
                FINISH: begin
                    // Wait for next start
                end
            endcase
        end
    end

endmodule

// Divider by 3 module
module divider_3(
    input clk,
    input rst_n,
    input start,
    input [63:0] dividend,
    output reg [63:0] quotient,
    output reg [1:0] remainder,
    output reg done
);

    reg [63:0] current_dividend;
    reg [1:0] current_remainder;
    reg [5:0] counter;
    reg running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quotient <= 64'd0;
            remainder <= 2'd0;
            current_dividend <= 64'd0;
            current_remainder <= 2'd0;
            counter <= 6'd0;
            running <= 1'b0;
            done <= 1'b0;
        end else begin
            if (start && !running) begin
                // Start new division
                running <= 1'b1;
                current_dividend <= dividend;
                current_remainder <= 2'd0;
                quotient <= 64'd0;
                counter <= 6'd0;
                done <= 1'b0;
            end else if (running) begin
                if (counter < 64) begin
                    // Shift remainder left by 1 and bring in next bit
                    current_remainder <= {current_remainder[1:0], current_dividend[63]];
                    current_dividend <= {current_dividend[62:0], 1'b0};

                    // If remainder >= 3, subtract 3 and set quotient bit
                    if (current_remainder >= 2'd3) begin
                        current_remainder <= current_remainder - 2'd3;
                        quotient <= {quotient[62:0], 1'b1};
                    end else begin
                        quotient <= {quotient[62:0], 1'b0};
                    end

                    counter <= counter + 6'd1;
                end else begin
                    running <= 1'b0;
                    remainder <= current_remainder;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule