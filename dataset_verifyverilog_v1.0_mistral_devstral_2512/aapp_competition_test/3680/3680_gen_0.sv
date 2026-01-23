module fence_posts (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] K,
    input wire [3:0] N,
    input wire [7:0] p [0:7],
    output reg [7:0] cuts,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_L = 3'd1;
    localparam [2:0] CHECK_L = 3'd2;
    localparam [2:0] COMPUTE_D = 3'd3;
    localparam [2:0] SORT_D = 3'd4;
    localparam [2:0] FIND_T = 3'd5;
    localparam [2:0] CALC_RESULT = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // Internal registers
    reg [2:0] state;
    reg [7:0] L;
    reg [7:0] max_L;
    reg [7:0] temp_sum;
    reg [7:0] D [0:7];
    reg [2:0] D_size;
    reg [7:0] prefix_sum;
    reg [2:0] t;
    reg [7:0] cuts_reg;
    reg done_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Helper function for division
    function [7:0] div_func;
        input [7:0] a, b;
        reg [7:0] count;
        reg [7:0] temp_a;
        begin
            count = 8'd0;
            temp_a = a;
            while (temp_a >= b) begin
                temp_a = temp_a - b;
                count = count + 8'd1;
            end
            div_func = count;
        end
    endfunction

    // Helper function for modulo
    function [7:0] mod_func;
        input [7:0] a, b;
        reg [7:0] temp_a;
        begin
            temp_a = a;
            while (temp_a >= b) begin
                temp_a = temp_a - b;
            end
            mod_func = temp_a;
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            L <= 8'd0;
            max_L <= 8'd0;
            temp_sum <= 8'd0;
            D_size <= 3'd0;
            prefix_sum <= 8'd0;
            t <= 3'd0;
            cuts_reg <= 8'd0;
            done_reg <= 1'b0;
            cuts <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    cuts <= 8'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FIND_L;
                    end
                end

                FIND_L: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find max pole length
                    max_L <= 8'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (p[i] > max_L) begin
                            max_L <= p[i];
                        end
                    end
                    L <= max_L;
                    state <= CHECK_L;
                end

                CHECK_L: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute total posts for current L
                    temp_sum <= 8'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < K) begin
                            temp_sum <= temp_sum + div_func(p[i], L);
                        end
                    end
                    if (temp_sum >= N) begin
                        state <= COMPUTE_D;
                    end else begin
                        L <= L - 8'd1;
                        if (L == 8'd0) begin
                            L <= 8'd1;
                        end
                    end
                end

                COMPUTE_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Build D array
                    D_size <= 3'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < K) begin
                            if (mod_func(p[i], L) == 8'd0) begin
                                D[D_size] <= div_func(p[i], L);
                                D_size <= D_size + 3'd1;
                            end
                        end
                    end
                    state <= SORT_D;
                end

                SORT_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort D array
                    integer i, j;
                    reg [7:0] temp;
                    for (i = 0; i < 7; i = i + 1) begin
                        for (j = 0; j < 7 - i; j = j + 1) begin
                            if (D[j] > D[j + 1]) begin
                                temp = D[j];
                                D[j] <= D[j + 1];
                                D[j + 1] <= temp;
                            end
                        end
                    end
                    state <= FIND_T;
                end

                FIND_T: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find maximum t
                    prefix_sum <= 8'd0;
                    t <= 3'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < D_size) begin
                            if (prefix_sum + D[i] <= N) begin
                                prefix_sum <= prefix_sum + D[i];
                                t <= t + 3'd1;
                            end else begin
                                i = 8; // break
                            end
                        end
                    end
                    state <= CALC_RESULT;
                end

                CALC_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute final result
                    cuts_reg <= N - t;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done_reg <= 1'b1;
                    cuts <= cuts_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done_reg <= 1'b0;
                    cuts <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Ensure done is only high for one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule