module profit_maximizer #(
    parameter NUM_PRODUCERS = 4,
    parameter NUM_CONSUMERS = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] producer_price [0:NUM_PRODUCERS-1],
    input wire [7:0] producer_date [0:NUM_PRODUCERS-1],
    
    input wire [7:0] consumer_price [0:NUM_CONSUMERS-1],
    input wire [7:0] consumer_date [0:NUM_CONSUMERS-1],
    
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_ST = 2'd2;
    
    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [15:0] max_profit;
    
    // Combinational logic for current pair
    wire valid_pair;
    wire [15:0] current_profit;
    
    assign valid_pair = (consumer_date[j] > producer_date[i]) && 
                        (consumer_price[j] > producer_price[i]);
    
    assign current_profit = (consumer_price[j] - producer_price[i]) * 
                            (consumer_date[j] - producer_date[i]);
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            max_profit <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd0;
                        j <= 4'd0;
                        max_profit <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    if (valid_pair && (current_profit > max_profit)) begin
                        max_profit <= current_profit;
                    end
                    
                    if (j < NUM_CONSUMERS - 1) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        if (i < NUM_PRODUCERS - 1) begin
                            i <= i + 4'd1;
                        end else begin
                            state <= DONE_ST;
                            result <= max_profit;
                        end
                    end
                end
                
                DONE_ST: begin
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