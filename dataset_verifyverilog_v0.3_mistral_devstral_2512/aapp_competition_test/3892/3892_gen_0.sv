module ToyTrain(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,
    input wire [7:0] m,
    input wire [6:0] a_i [0:199],
    input wire [6:0] b_i [0:199],
    output reg [31:0] ans_i [0:99],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_CANDIES = 3'd1;
    localparam [2:0] COMPUTE_ANSWERS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] candy_index;
    reg [6:0] station_index;
    reg [7:0] count [0:99];
    reg [6:0] min_dist [0:99];
    reg [31:0] current_max;
    reg [31:0] temp_value;
    reg [6:0] j;
    reg [31:0] value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            candy_index <= 8'd0;
            station_index <= 7'd0;
            done <= 1'b0;
            for (j = 0; j < 100; j = j + 1) begin
                count[j] <= 8'd0;
                min_dist[j] <= 7'd127;
                ans_i[j] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS_CANDIES;
                        candy_index <= 8'd0;
                    end
                end

                PROCESS_CANDIES: begin
                    if (candy_index < m) begin
                        // Process candy
                        reg [6:0] a_0idx = a_i[candy_index] - 7'd1;
                        reg [6:0] b_0idx = b_i[candy_index] - 7'd1;
                        reg [6:0] d;
                        if (b_0idx >= a_0idx) begin
                            d = b_0idx - a_0idx;
                        end else begin
                            d = n + b_0idx - a_0idx;
                        end
                        count[a_0idx] <= count[a_0idx] + 8'd1;
                        if (d < min_dist[a_0idx]) begin
                            min_dist[a_0idx] <= d;
                        end
                        candy_index <= candy_index + 8'd1;
                    end else begin
                        state <= COMPUTE_ANSWERS;
                        station_index <= 7'd0;
                    end
                end

                COMPUTE_ANSWERS: begin
                    if (station_index < n) begin
                        current_max <= 32'd0;
                        for (j = 0; j < n; j = j + 1) begin
                            if (count[j] > 8'd0) begin
                                if (j >= station_index) begin
                                    value = (j - station_index) + (count[j] - 8'd1) * n + min_dist[j];
                                end else begin
                                    value = (n + j - station_index) + (count[j] - 8'd1) * n + min_dist[j];
                                end
                                if (value > current_max) begin
                                    current_max <= value;
                                end
                            end
                        end
                        ans_i[station_index] <= current_max;
                        station_index <= station_index + 7'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule