module permutation_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [3:0] t_idx,
    input wire [4:0] t_val,
    input wire t_valid,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    
    // States
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] n;
    reg [4:0] t_ram [0:15];
    reg [15:0] visited;
    reg [3:0] i_reg;
    reg [3:0] current;
    reg [3:0] cycle_length;
    reg [3:0] even_cycle_count;
    reg [31:0] power_result;
    reg [3:0] power_exp;
    reg [31:0] power_base;
    reg [3:0] power_iter;
    reg [3:0] load_count;
    reg [3:0] process_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 4'd0;
            visited <= 16'd0;
            i_reg <= 4'd0;
            current <= 4'd0;
            cycle_length <= 4'd0;
            even_cycle_count <= 4'd0;
            power_result <= 32'd0;
            power_exp <= 4'd0;
            power_base <= 32'd0;
            power_iter <= 4'd0;
            load_count <= 4'd0;
            process_count <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            ready <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        ready <= 1'b0;
                        n <= len;
                        load_count <= 4'd0;
                        visited <= 16'd0;
                        i_reg <= 4'd0;
                        current <= 4'd0;
                        cycle_length <= 4'd0;
                        even_cycle_count <= 4'd0;
                        power_result <= 32'd0;
                        power_exp <= 4'd0;
                        power_base <= 32'd0;
                        power_iter <= 4'd0;
                        process_count <= 4'd0;
                    end
                end
                
                LOAD: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    if (t_valid) begin
                        t_ram[t_idx] <= t_val;
                        load_count <= load_count + 4'd1;
                        if (load_count == n) begin
                            state <= PROCESS;
                            i_reg <= 4'd0;
                            visited <= 16'd0;
                            even_cycle_count <= 4'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    if (i_reg < n) begin
                        if (!visited[i_reg]) begin
                            current <= i_reg;
                            cycle_length <= 4'd0;
                            process_count <= 4'd0;
                        end else begin
                            i_reg <= i_reg + 4'd1;
                        end
                    end else begin
                        state <= COMPUTE;
                        power_exp <= even_cycle_count;
                        power_base <= 32'd2;
                        power_result <= 32'd1;
                        power_iter <= 4'd0;
                    end
                    
                    if (process_count < n) begin
                        if (!visited[current]) begin
                            visited[current] <= 1'b1;
                            cycle_length <= cycle_length + 4'd1;
                            current <= t_ram[current] - 5'd1;
                            process_count <= process_count + 4'd1;
                        end else begin
                            if (cycle_length % 2'd2 == 2'd0 && cycle_length > 2'd0) begin
                                even_cycle_count <= even_cycle_count + 4'd1;
                            end
                            i_reg <= i_reg + 4'd1;
                        end
                    end
                end
                
                COMPUTE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    if (power_iter < power_exp) begin
                        power_result <= (power_result * power_base) % MOD;
                        power_iter <= power_iter + 4'd1;
                    end else begin
                        state <= DONE;
                        result <= power_result;
                    end
                end
                
                DONE: begin
                    ready <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule