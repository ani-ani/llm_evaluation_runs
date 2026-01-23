module even_pair_counter (
    input clk,
    input [7:0] data_in,
    input [2:0] index,
    input load,
    input compute,
    output reg [4:0] result,
    output reg valid
);

    reg [7:0] data_array [0:7];
    reg [2:0] state;
    reg [3:0] count_even;
    reg [3:0] count_odd;
    reg [4:0] pairs_even;
    reg [4:0] pairs_odd;

    parameter IDLE = 3'b000;
    parameter LOADING = 3'b001;
    parameter COMPUTING = 3'b010;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (load) begin
                    state <= LOADING;
                end else if (compute) begin
                    state <= COMPUTING;
                end
            end
            LOADING: begin
                data_array[index] <= data_in;
                if (!load) begin
                    state <= IDLE;
                end
            end
            COMPUTING: begin
                count_even <= 0;
                count_odd <= 0;
                for (int i = 0; i < 8; i = i + 1) begin
                    if (data_array[i][0] == 1'b0) begin
                        count_even <= count_even + 1;
                    end else begin
                        count_odd <= count_odd + 1;
                    end
                end
                pairs_even <= (count_even * (count_even - 1)) >> 1;
                pairs_odd <= (count_odd * (count_odd - 1)) >> 1;
                result <= pairs_even + pairs_odd;
                valid <= 1'b1;
                state <= IDLE;
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end

endmodule