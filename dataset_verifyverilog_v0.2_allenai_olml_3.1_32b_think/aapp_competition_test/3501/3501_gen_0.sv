module camel_race_bets (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] n,
    input [4:0] a [0:31],
    input [4:0] b [0:31],
    input [4:0] c [0:31],
    output reg [31:0] result,
    output reg done
);

reg [2:0] state;
localparam IDLE = 3'b000, SETUP = 3'b001, CHECK = 3'b010, DONE = 3'b100;
reg [4:0] n_val;
reg [4:0] a_reg [0:31];
reg [4:0] b_reg [0:31];
reg [4:0] c_reg [0:31];
reg [4:0] pos_a [0:31];
reg [4:0] pos_b [0:31];
reg [4:0] pos_c [0:31];
reg [4:0] i;
reg [4:0] j;
reg [31:0] pair_count;
reg done_reg;

// For building position tables
reg [4:0] build_i;
reg [4:0] build_p;
reg [2:0] build_array;
reg build_done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        n_val <= 5'b0;
        a_reg <= 32'd0;
        b_reg <= 32'd0;
        c_reg <= 32'd0;
        pos_a <= 32'd0;
        pos_b <= 32'd0;
        pos_c <= 32'd0;
        i <= 32'd0;
        j <= 32'd0;
        pair_count <= 32'd0;
        done_reg <= 1'b0;
        build_i <= 32'd0;
        build_p <= 32'd0;
        build_array <= 3'b000;
        build_done <= 1'b0;
    end else begin
        case (state)
            IDLE: if (start) state <= SETUP; else state <= IDLE;
            SETUP:  
                if (n_val == 0) begin
                    state <= CHECK;
                end else if (!build_done) begin
                    // Latch inputs if not already done? Or latch on entry to SETUP?
                    // Assume we latched on entering SETUP
                    if (build_i == 32'd0) begin
                        build_i <= 32'd1; // start processing
                    end
                    if (build_i < n_val) begin
                        if (build_array == 3'b000) begin // Processing array a for current build_i
                            if (a_reg[build_p] == build_i) begin
                                pos_a[build_i] <= build_p;
                                build_array <= 3'b001; // move to array b
                                build_p <= 32'd0;
                            end else begin
                                build_p <= build_p + 1;
                                if (build_p == n_val) begin
                                    build_array <= 3'b001;
                                    build_p <= 32'd0;
                                end
                            end
                        end else if (build_array == 3'b001) begin // array b
                            if (b_reg[build_p] == build_i) begin
                                pos_b[build_i] <= build_p;
                                build_array <= 3'b010;
                                build_p <= 32'd0;
                            end else begin
                                build_p <= build_p +1;
                                if (build_p == n_val) begin
                                    build_array <= 3'b010;
                                    build_p <= 32'd0;
                                end
                            end
                        end else if (build_array == 3'b010) begin // array c
                            if (c_reg[build_p] == build_i) begin
                                pos_c[build_i] <= build_p;
                                build_i <= build_i +1;
                                build_array <= 3'b000;
                                build_p <= 32'd0;
                                if (build_i == n_val) begin
                                    build_done <= 1'b1;
                                end
                            end else begin
                                build_p <= build_p +1;
                                if (build_p == n_val) begin
                                    build_array <= 3'b000;
                                    build_p <= 32'd0;
                                    build_i <= build_i +1;
                                    if (build_i == n_val) begin
                                        build_done <= 1'b1;
                                    end
                                end
                            end
                        end
                    end
                end else begin
                    state <= CHECK;
                end
            end
            CHECK: begin
                if (i == 0) begin
                    i <= 1;
                    j <= 1;
                end else if (j >= n_val) begin
                    if (i < n_val -1) begin
                        i <= i +1;
                        j <= i +1;
                    end else begin
                        pair_count <= pair_count; // retain result
                        state <= DONE;
                        done_reg <= 1'b1;
                    end
                end else begin
                    // Check all three position tables
                    if ( (pos_a[i] < pos_a[j]) && (pos_b[i] < pos_b[j]) && (pos_c[i] < pos_c[j]) ) begin
                        pair_count <= pair_count +1;
                    end
                    j <= j +1;
                end
            end
            DONE: state <= DONE;
        endcase
    end
endmodule