module dog_chain_solver (
    input clk,
    input rst_n, // active low
    input start,
    input [15:0] x1, y1, x2, y2,
    input [15:0] L,
    output reg [15:0] R_result,
    output reg done
);

    reg [31:0] d_fixed;
    reg [15:0] current_R;
    reg [31:0] area_fixed;
    reg [15:0] max_R = 256;
    reg [31:0] L_fixed = L << 16;
    reg state;
    parameter S_IDLE = 3'd0;
    parameter S_CALC_D = 3'd1;
    parameter S_SEARCH = 3'd2;
    parameter S_DONE = 3'd3;

    always @(posedge clk) begin
        if (!rst_n) begin
            d_fixed <= 32'd0;
            current_R <= 32'd0;
            R_result <= 16'd0;
            done <= 1'b0;
            state <= S_IDLE;
        end else begin
            if (state == S_IDLE) begin
                if (start) state <= S_CALC_D;
            end
            else if (state == S_CALC_D) begin
                // Compute distance (dummy)
                d_fixed <= 32'd0;
                state <= S_SEARCH;
                current_R <= 16'd1;
            end
            else if (state == S_SEARCH) begin
                if (current_R <= max_R) begin
                    // Compute area (dummy)
                    area_fixed <= 32'd0;
                    if (area_fixed >= L_fixed) begin
                        R_result <= current_R;
                        done <= 1'b1;
                        state <= S_DONE;
                    end else begin
                        current_R <= current_R + 1;
                    end
                end else begin
                    R_result <= max_R;
                    done <= 1'b1;
                    state <= S_DONE;
                end
            end
            else if (state == S_DONE) begin
                // Stay in done state
            end
        end
    end

    // Tasks for distance and area calculation would be here
endmodule