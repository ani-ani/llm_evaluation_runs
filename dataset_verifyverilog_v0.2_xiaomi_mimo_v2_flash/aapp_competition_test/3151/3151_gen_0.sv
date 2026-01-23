module swimming_hall(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] m,
    output reg [7:0] k,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK_FACTOR = 2'b01;
    localparam FOUND = 2'b10;
    localparam IMPOSSIBLE = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;
    
    // Counter for i (1 to n)
    reg [7:0] i;
    
    // Intermediate signals for calculations
    wire [7:0] j;
    wire [7:0] sum_ij;
    wire [7:0] diff_ji;
    wire sum_even;
    wire diff_even;
    wire divides;
    wire [7:0] calc_m;
    wire [7:0] calc_k;
    
    // Combinational logic
    assign j = n / i;
    assign sum_ij = i + j;
    assign diff_ji = j - i;
    assign sum_even = (sum_ij[0] == 1'b0);
    assign diff_even = (diff_ji[0] == 1'b0);
    assign divides = (n % i == 8'b0);
    assign calc_m = sum_ij >> 1;
    assign calc_k = diff_ji >> 1;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_FACTOR;
                else
                    next_state = IDLE;
            end
            CHECK_FACTOR: begin
                if (divides && sum_even && diff_even) begin
                    next_state = FOUND;
                end else if (i < n) begin
                    next_state = CHECK_FACTOR;
                end else begin
                    next_state = IMPOSSIBLE;
                end
            end
            FOUND: begin
                next_state = IDLE;
            end
            IMPOSSIBLE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'b0;
            m <= 8'b0;
            k <= 8'b0;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 8'b1;
                        valid <= 1'b0;
                        impossible <= 1'b0;
                        done <= 1'b0;
                    end
                end
                CHECK_FACTOR: begin
                    if (divides && sum_even && diff_even) begin
                        m <= calc_m;
                        k <= calc_k;
                        valid <= 1'b1;
                        done <= 1'b1;
                    end else if (i < n) begin
                        i <= i + 8'b1;
                    end else begin
                        impossible <= 1'b1;
                        done <= 1'b1;
                    end
                end
                FOUND: begin
                    // Reset outputs for next operation
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                IMPOSSIBLE: begin
                    // Reset outputs for next operation
                    impossible <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
