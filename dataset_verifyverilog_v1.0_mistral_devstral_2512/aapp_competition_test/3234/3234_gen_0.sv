module packing_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] N,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_W = 3'd2;
    localparam [2:0] CHECK_RATIO = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] INCREMENT_H = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [15:0] H;
    reg [15:0] W;
    reg [15:0] min_empty;
    reg [31:0] area;
    reg [15:0] div_a;
    reg [15:0] div_b;
    reg [15:0] div_quotient;
    reg div_done;
    reg [15:0] div_rem;
    reg [7:0] div_cycles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            H <= 16'd0;
            W <= 16'd0;
            min_empty <= 16'd0;
            area <= 32'd0;
            div_a <= 16'd0;
            div_b <= 16'd0;
            div_quotient <= 16'd0;
            div_done <= 1'b1;
            div_rem <= 16'd0;
            div_cycles <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    H <= 16'd1;
                    min_empty <= 16'hFFFF;
                    state <= COMPUTE_W;
                end
                
                COMPUTE_W: begin
                    div_a <= N + H - 16'd1;
                    div_b <= H;
                    div_quotient <= 16'd0;
                    div_rem <= N + H - 16'd1;
                    div_cycles <= 8'd0;
                    div_done <= 1'b0;
                    state <= CHECK_RATIO;
                end
                
                CHECK_RATIO: begin
                    if (!div_done) begin
                        if (div_cycles < 8'd16) begin
                            if (div_rem >= div_b) begin
                                div_rem <= div_rem - div_b;
                                div_quotient <= div_quotient + 16'd1;
                            end
                            div_cycles <= div_cycles + 8'd1;
                        end else begin
                            if (div_rem > 16'd0) begin
                                div_quotient <= div_quotient + 16'd1;
                            end
                            div_done <= 1'b1;
                        end
                    end else begin
                        W <= div_quotient;
                        if ((W * 16'd2 >= H) && (W <= H * 16'd2)) begin
                            area <= W * H;
                        end else begin
                            area <= 32'hFFFFFFFF;
                        end
                        state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    if (area < 32'hFFFFFFFF && area >= N) begin
                        if (area - N < min_empty) begin
                            min_empty <= area - N;
                        end
                    end
                    state <= INCREMENT_H;
                end
                
                INCREMENT_H: begin
                    H <= H + 16'd1;
                    if (H > 16'd256) begin
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE_W;
                    end
                end
                
                FINISH: begin
                    result <= min_empty;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule