module profit_maximizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] producer_price_0,
    input wire [7:0] producer_price_1,
    input wire [7:0] producer_price_2,
    input wire [7:0] producer_price_3,
    input wire [7:0] producer_date_0,
    input wire [7:0] producer_date_1,
    input wire [7:0] producer_date_2,
    input wire [7:0] producer_date_3,
    input wire [7:0] consumer_price_0,
    input wire [7:0] consumer_price_1,
    input wire [7:0] consumer_price_2,
    input wire [7:0] consumer_price_3,
    input wire [7:0] consumer_date_0,
    input wire [7:0] consumer_date_1,
    input wire [7:0] consumer_date_2,
    input wire [7:0] consumer_date_3,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    reg [1:0] state;
    reg [1:0] i;  // Producer index
    reg [1:0] j;  // Consumer index
    reg [15:0] max_profit;
    reg [15:0] current_profit;
    reg valid_pair;

    // Temporary storage for current values
    reg [7:0] p_price;
    reg [7:0] p_date;
    reg [7:0] c_price;
    reg [7:0] c_date;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 2'd0;
            j <= 2'd0;
            max_profit <= 16'd0;
            current_profit <= 16'd0;
            p_price <= 8'd0;
            p_date <= 8'd0;
            c_price <= 8'd0;
            c_date <= 8'd0;
            valid_pair <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 2'd0;
                        j <= 2'd0;
                        max_profit <= 16'd0;
                    end
                end

                COMPUTE: begin
                    // Get current producer values
                    case (i)
                        2'd0: begin
                            p_price <= producer_price_0;
                            p_date <= producer_date_0;
                        end
                        2'd1: begin
                            p_price <= producer_price_1;
                            p_date <= producer_date_1;
                        end
                        2'd2: begin
                            p_price <= producer_price_2;
                            p_date <= producer_date_2;
                        end
                        2'd3: begin
                            p_price <= producer_price_3;
                            p_date <= producer_date_3;
                        end
                        default: begin
                            p_price <= 8'd0;
                            p_date <= 8'd0;
                        end
                    endcase

                    // Get current consumer values
                    case (j)
                        2'd0: begin
                            c_price <= consumer_price_0;
                            c_date <= consumer_date_0;
                        end
                        2'd1: begin
                            c_price <= consumer_price_1;
                            c_date <= consumer_date_1;
                        end
                        2'd2: begin
                            c_price <= consumer_price_2;
                            c_date <= consumer_date_2;
                        end
                        2'd3: begin
                            c_price <= consumer_price_3;
                            c_date <= consumer_date_3;
                        end
                        default: begin
                            c_price <= 8'd0;
                            c_date <= 8'd0;
                        end
                    endcase

                    // Check validity and calculate profit
                    if ((c_date > p_date) && (c_price > p_price)) begin
                        valid_pair <= 1'b1;
                        current_profit <= (c_price - p_price) * (c_date - p_date);
                    end else begin
                        valid_pair <= 1'b0;
                        current_profit <= 16'd0;
                    end

                    // Update max profit
                    if (valid_pair && (current_profit > max_profit)) begin
                        max_profit <= current_profit;
                    end

                    // Next pair
                    if (j < 2'd3) begin
                        j <= j + 1;
                    end else begin
                        j <= 2'd0;
                        if (i < 2'd3) begin
                            i <= i + 1;
                        end else begin
                            state <= DONE;
                            result <= max_profit;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule