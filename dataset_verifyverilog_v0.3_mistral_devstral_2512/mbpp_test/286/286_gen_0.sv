module max_sub_array_repeated(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr_0,
    input wire [15:0] arr_1,
    input wire [15:0] arr_2,
    input wire [15:0] arr_3,
    input wire [15:0] arr_4,
    input wire [15:0] arr_5,
    input wire [15:0] arr_6,
    input wire [15:0] arr_7,
    input wire [3:0] n,
    input wire [3:0] k,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] iter_count;
    reg [3:0] arr_index;
    reg [2:0] cycle_delay;
    reg signed [15:0] current_val;
    reg signed [31:0] max_ending_here;
    reg signed [31:0] max_so_far;

    always @(*) begin
        case(arr_index)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            4'd7: current_val = arr_7;
            default: current_val = 16'sd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            max_so_far <= 32'sd0;
            max_ending_here <= 32'sd0;
            iter_count <= 8'd0;
            arr_index <= 4'd0;
            cycle_delay <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        iter_count <= 8'd0;
                        arr_index <= 4'd0;
                        max_so_far <= 32'sd0;
                        max_ending_here <= 32'sd0;
                        cycle_delay <= 3'd0;
                    end
                end

                COMPUTE: begin
                    if (cycle_delay == 3'd0) begin
                        if (iter_count < (n * k)) begin
                            if (max_ending_here + current_val > 32'sd0) begin
                                max_ending_here <= max_ending_here + current_val;
                            end else begin
                                max_ending_here <= 32'sd0;
                            end
                            cycle_delay <= 3'd1;
                        end else begin
                            state <= FINISH;
                            cycle_delay <= 3'd0;
                        end
                    end else if (cycle_delay == 3'd1) begin
                        if (max_ending_here > max_so_far) begin
                            max_so_far <= max_ending_here;
                        end
                        cycle_delay <= 3'd2;
                    end else if (cycle_delay == 3'd2) begin
                        iter_count <= iter_count + 8'd1;
                        arr_index <= (arr_index + 4'd1) % n;
                        cycle_delay <= 3'd0;
                    end
                end

                FINISH: begin
                    result <= max_so_far;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule