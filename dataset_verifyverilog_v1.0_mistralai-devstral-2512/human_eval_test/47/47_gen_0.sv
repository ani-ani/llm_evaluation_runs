module median_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] data_in,
    input wire data_in_valid,
    input wire [3:0] len,
    output reg signed [7:0] data_out,
    output reg [3:0] data_out_addr,
    output reg data_out_valid,
    output reg done,
    output reg signed [15:0] result
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILL = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] element_count;
    reg [7:0] swap_count;
    reg [3:0] i_reg, j_reg, min_idx_reg;
    reg [7:0] mem [0:15];
    reg [7:0] temp_data;
    reg [3:0] temp_addr;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            data_out <= 8'd0;
            data_out_addr <= 4'd0;
            data_out_valid <= 1'b0;
            element_count <= 8'd0;
            swap_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            min_idx_reg <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize memory
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                mem[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    data_out_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        element_count <= 8'd0;
                        next_state <= FILL;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FILL: begin
                    data_out_valid <= 1'b0;
                    if (data_in_valid) begin
                        mem[element_count] <= data_in;
                        element_count <= element_count + 8'd1;
                        if (element_count == len) begin
                            next_state <= SORT;
                            i_reg <= 4'd0;
                            j_reg <= 4'd0;
                            min_idx_reg <= 4'd0;
                            swap_count <= 8'd0;
                        end
                    end
                end

                SORT: begin
                    data_out_valid <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (swap_count < 8'd256) begin
                        if (j_reg < len) begin
                            if (mem[j_reg] < mem[min_idx_reg]) begin
                                min_idx_reg <= j_reg;
                            end
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            // Swap if needed
                            if (min_idx_reg != i_reg) begin
                                temp_data <= mem[i_reg];
                                temp_addr <= i_reg;
                                mem[i_reg] <= mem[min_idx_reg];
                                data_out <= mem[min_idx_reg];
                                data_out_addr <= i_reg;
                                data_out_valid <= 1'b1;
                                
                                mem[min_idx_reg] <= temp_data;
                                data_out <= temp_data;
                                data_out_addr <= min_idx_reg;
                                data_out_valid <= 1'b1;
                            end
                            i_reg <= i_reg + 4'd1;
                            j_reg <= i_reg;
                            min_idx_reg <= i_reg;
                            swap_count <= swap_count + 8'd1;
                            
                            if (i_reg == len - 4'd1) begin
                                next_state <= COMPUTE;
                            end
                        end
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    data_out_valid <= 1'b0;
                    if (len[0] == 1'b1) begin
                        // Odd length
                        result <= {mem[len/2], 8'b00000000};
                    end else begin
                        // Even length
                        reg signed [15:0] sum;
                        reg signed [15:0] avg;
                        sum = mem[len/2 - 4'd1] + mem[len/2];
                        
                        if (sum[0] == 1'b1) begin
                            // Odd sum - fractional .5
                            avg = {sum[15:1], 1'b1, 7'b0};
                        end else begin
                            // Even sum - fractional .0
                            avg = {sum[15:1], 8'b0};
                        end
                        result <= avg;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    data_out_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule