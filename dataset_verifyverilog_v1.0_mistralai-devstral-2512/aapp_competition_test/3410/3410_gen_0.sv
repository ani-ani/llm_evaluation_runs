module quadrilateral_area_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x [0:11],
    input wire [15:0] y [0:11],
    input wire [3:0] n,
    output reg [19:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    // Combination counters
    reg [3:0] i, j, k, l;
    reg [3:0] next_i, next_j, next_k, next_l;
    
    // Area calculation registers
    reg signed [31:0] area_sum;
    reg signed [31:0] temp_area;
    reg signed [31:0] cross1, cross2;
    
    // Modulo operation registers
    reg [19:0] modulo_result;
    reg [19:0] mod_counter;
    localparam [19:0] MODULO = 20'd1000003;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 20'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            next_i <= 4'd0;
            next_j <= 4'd0;
            next_k <= 4'd0;
            next_l <= 4'd0;
            
            area_sum <= 32'd0;
            temp_area <= 32'd0;
            cross1 <= 32'd0;
            cross2 <= 32'd0;
            
            modulo_result <= 20'd0;
            mod_counter <= 20'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd0;
                        j <= 4'd1;
                        k <= 4'd2;
                        l <= 4'd3;
                        area_sum <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate twice the area for current combination (i,j,k,l)
                    // Using shoelace formula for quadrilateral
                    cross1 <= ($signed(x[j]) - $signed(x[i])) * ($signed(y[l]) - $signed(y[i]));
                    cross2 <= ($signed(x[l]) - $signed(x[i])) * ($signed(y[j]) - $signed(y[i]));
                    temp_area <= cross1 - cross2;
                    
                    cross1 <= ($signed(x[l]) - $signed(x[k])) * ($signed(y[j]) - $signed(y[k]));
                    cross2 <= ($signed(x[j]) - $signed(x[k])) * ($signed(y[l]) - $signed(y[k]));
                    temp_area <= temp_area + (cross1 - cross2);
                    
                    // Take absolute value
                    if (temp_area[31]) begin
                        temp_area <= -temp_area;
                    end
                    
                    // Add to total sum
                    area_sum <= area_sum + temp_area;
                    
                    // Generate next combination
                    next_l <= l + 4'd1;
                    if (next_l >= n) begin
                        next_l <= 4'd0;
                        next_k <= k + 4'd1;
                        if (next_k >= n - 4'd1) begin
                            next_k <= 4'd0;
                            next_j <= j + 4'd1;
                            if (next_j >= n - 4'd2) begin
                                next_j <= 4'd0;
                                next_i <= i + 4'd1;
                                if (next_i >= n - 4'd3) begin
                                    next_i <= 4'd0;
                                    state <= FINISH;
                                end else begin
                                    next_i <= i + 4'd1;
                                    next_j <= next_i + 4'd1;
                                    next_k <= next_j + 4'd1;
                                    next_l <= next_k + 4'd1;
                                end
                            end else begin
                                next_j <= j + 4'd1;
                                next_k <= next_j + 4'd1;
                                next_l <= next_k + 4'd1;
                            end
                        end else begin
                            next_k <= k + 4'd1;
                            next_l <= next_k + 4'd1;
                        end
                    end else begin
                        next_l <= l + 4'd1;
                    end
                    
                    // Update counters
                    i <= next_i;
                    j <= next_j;
                    k <= next_k;
                    l <= next_l;
                    
                    // Check for completion or timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Compute modulo 1000003
                    modulo_result <= area_sum[19:0];
                    mod_counter <= 20'd0;
                    
                    // Division-less modulo using subtraction
                    while (mod_counter < MODULO && modulo_result >= MODULO) begin
                        modulo_result <= modulo_result - MODULO;
                        mod_counter <= mod_counter + 20'd1;
                    end
                    
                    result <= modulo_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule