module airplane_construction(
    input clk,
    input rst_n,
    input start,
    input [15:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] dep_mask_0, dep_mask_1, dep_mask_2, dep_mask_3, dep_mask_4, dep_mask_5, dep_mask_6, dep_mask_7,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] k_index;
    reg [3:0] i_index;
    reg [31:0] min_val;
    reg [31:0] dp [0:7];
    reg [31:0] a [0:7];
    reg [7:0] dep_mask [0:7];
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            k_index <= 4'd0;
            i_index <= 4'd0;
            min_val <= 32'd0;
            for (j = 0; j < 8; j = j + 1) begin
                dp[j] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        k_index <= 4'd0;
                        i_index <= 4'd0;
                        min_val <= 32'hFFFFFFFF;
                        for (j = 0; j < 8; j = j + 1) begin
                            dp[j] <= 32'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (k_index < 8) begin
                        if (i_index == 0) begin
                            dp[0] <= (k_index == 0) ? 32'd0 : a[0];
                            i_index <= 4'd1;
                        end else begin
                            reg [31:0] max_val;
                            max_val = 32'd0;
                            for (j = 0; j < 8; j = j + 1) begin
                                if (dep_mask[i_index][j] && dp[j] > max_val) begin
                                    max_val = dp[j];
                                end
                            end
                            dp[i_index] <= max_val + ((i_index == k_index) ? 32'd0 : a[i_index]);

                            if (i_index == 7) begin
                                if (k_index == 0) begin
                                    min_val <= dp[7];
                                end else if (dp[7] < min_val) begin
                                    min_val <= dp[7];
                                end
                                i_index <= 4'd0;
                                k_index <= k_index + 4'd1;
                            end else begin
                                i_index <= i_index + 4'd1;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_val;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Assign input arrays
    always @(*) begin
        a[0] = {16'b0, a_0};
        a[1] = {16'b0, a_1};
        a[2] = {16'b0, a_2};
        a[3] = {16'b0, a_3};
        a[4] = {16'b0, a_4};
        a[5] = {16'b0, a_5};
        a[6] = {16'b0, a_6};
        a[7] = {16'b0, a_7};
        
        dep_mask[0] = dep_mask_0;
        dep_mask[1] = dep_mask_1;
        dep_mask[2] = dep_mask_2;
        dep_mask[3] = dep_mask_3;
        dep_mask[4] = dep_mask_4;
        dep_mask[5] = dep_mask_5;
        dep_mask[6] = dep_mask_6;
        dep_mask[7] = dep_mask_7;
    end

endmodule