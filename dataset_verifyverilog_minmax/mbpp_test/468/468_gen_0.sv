module max_inc_subseq_product (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [31:0] max_product,
    output reg done
);

    // Internal storage for input array
    reg [7:0] arr_reg [0:7];
    // DP product array
    reg [31:0] mpis [0:7];
    // Running maximum product
    reg [31:0] max_reg;
    // Cycle counter
    reg [2:0] cnt;
    // Flag to indicate that computation has started
    reg started;

    // Temporary variables for combinatorial calculations
    reg [31:0] new_prod, mpis_new, max_new;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal storage
            for (int i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 8'b0;
                mpis[i] <= 32'b0;
            end
            max_reg <= 32'b0;
            cnt <= 3'b0;
            started <= 1'b0;
            done <= 1'b0;
            max_product <= 32'b0;
        end else begin
            // Latch input array and initialize DP on start pulse
            if (start && !started) begin
                for (int i = 0; i < 8; i = i + 1) begin
                    arr_reg[i] <= arr[i];
                    mpis[i] <= {24'b0, arr[i]};
                end
                max_reg <= {24'b0, arr[0]};
                cnt <= 3'b0;
                started <= 1'b1;
                done <= 1'b0;
                max_product <= 32'b0;
            end else if (started) begin
                if (cnt < 3'd7) begin
                    // Compute product for current index
                    new_prod = mpis[cnt] * {24'b0, arr_reg[cnt+1]};
                    // Determine new mpis value
                    if (arr_reg[cnt] < arr_reg[cnt+1]) begin
                        mpis_new = (new_prod > mpis[cnt+1]) ? new_prod : mpis[cnt+1];
                    end else begin
                        mpis_new = mpis[cnt+1];
                    end
                    // Update running maximum
                    max_new = (mpis_new > max_reg) ? mpis_new : max_reg;
                    // Commit updates
                    mpis[cnt+1] <= mpis_new;
                    max_reg <= max_new;
                    cnt <= cnt + 1;
                end else begin
                    // All propagations completed – result is ready
                    done <= 1'b1;
                    max_product <= max_reg;
                end
            end
        end
    end

endmodule