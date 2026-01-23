module BeachFoodTruck #(
    parameter N = 5,
    parameter DATA_WIDTH = 8,
    parameter IDX_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [IDX_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire wr_en,
    output reg [IDX_WIDTH-1:0] optimal_pos,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Memory: N huts
    reg [DATA_WIDTH-1:0] huts [0:N-1];
    
    // Internal signals
    reg [12:0] total; // 13 bits for sum of 5*255 = 1275
    reg [4:0] i; // Counter for huts
    reg [12:0] prefix_sum [0:N-1]; // Prefix sums
    reg [13:0] diff [0:N-1]; // Diff values (13 bits for signed)
    reg [13:0] min_diff;
    reg [IDX_WIDTH-1:0] best_pos;
    
    integer j;
    
    // Memory write logic
    always @(posedge clk) begin
        if (wr_en && (addr < N)) begin
            huts[addr] <= data_in;
        end
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            optimal_pos <= {IDX_WIDTH{1'b0}};
            total <= 13'd0;
            min_diff <= 14'd0;
            best_pos <= {IDX_WIDTH{1'b0}};
            for (j = 0; j < N; j = j + 1) begin
                prefix_sum[j] <= 13'd0;
                diff[j] <= 14'd0;
                huts[j] <= 8'd0;
            end
            i <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 5'd0;
                    total <= 13'd0;
                    min_diff <= 14'h7FFF; // Large positive value
                    best_pos <= {IDX_WIDTH{1'b0}};
                    for (j = 0; j < N; j = j + 1) begin
                        prefix_sum[j] <= 13'd0;
                        diff[j] <= 14'd0;
                    end
                end
                
                COMPUTE: begin
                    case (i)
                        5'd0: begin
                            // Calculate total and prefix sums in parallel
                            total <= huts[0] + huts[1] + huts[2] + huts[3] + huts[4];
                            prefix_sum[0] <= 13'd0;
                            prefix_sum[1] <= huts[0];
                            prefix_sum[2] <= huts[0] + huts[1];
                            prefix_sum[3] <= huts[0] + huts[1] + huts[2];
                            prefix_sum[4] <= huts[0] + huts[1] + huts[2] + huts[3];
                            i <= 5'd1;
                        end
                        5'd1: begin
                            // Calculate diff for position 0
                            // diff = max(0, |2*prefix[0] + hut[0] - total| - (hut[0] & 1))
                            diff[0] <= compute_diff(prefix_sum[0], huts[0], total);
                            i <= 5'd2;
                        end
                        5'd2: begin
                            // Calculate diff for position 1
                            diff[1] <= compute_diff(prefix_sum[1], huts[1], total);
                            i <= 5'd3;
                        end
                        5'd3: begin
                            // Calculate diff for position 2
                            diff[2] <= compute_diff(prefix_sum[2], huts[2], total);
                            i <= 5'd4;
                        end
                        5'd4: begin
                            // Calculate diff for position 3
                            diff[3] <= compute_diff(prefix_sum[3], huts[3], total);
                            i <= 5'd5;
                        end
                        5'd5: begin
                            // Calculate diff for position 4
                            diff[4] <= compute_diff(prefix_sum[4], huts[4], total);
                            i <= 5'd6;
                        end
                        5'd6: begin
                            // Find minimum diff
                            if (diff[0] < min_diff) begin
                                min_diff <= diff[0];
                                best_pos <= 3'd0;
                            end
                            i <= 5'd7;
                        end
                        5'd7: begin
                            if (diff[1] < min_diff) begin
                                min_diff <= diff[1];
                                best_pos <= 3'd1;
                            end
                            i <= 5'd8;
                        end
                        5'd8: begin
                            if (diff[2] < min_diff) begin
                                min_diff <= diff[2];
                                best_pos <= 3'd2;
                            end
                            i <= 5'd9;
                        end
                        5'd9: begin
                            if (diff[3] < min_diff) begin
                                min_diff <= diff[3];
                                best_pos <= 3'd3;
                            end
                            i <= 5'd10;
                        end
                        5'd10: begin
                            if (diff[4] < min_diff) begin
                                min_diff <= diff[4];
                                best_pos <= 3'd4;
                            end
                            i <= 5'd11;
                        end
                        5'd11: begin
                            // Store result
                            optimal_pos <= best_pos;
                            i <= 5'd12;
                        end
                        default: begin
                            i <= 5'd13;
                        end
                    endcase
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = (i == 5'd12) ? DONE_STATE : COMPUTE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Helper function to compute diff (combinational)
    function automatic [13:0] compute_diff;
        input [12:0] prefix;
        input [7:0] hut;
        input [12:0] total;
        reg [13:0] abs_val;
        reg [13:0] adjusted;
        reg [13:0] result;
        begin
            // Compute 2*prefix + hut - total
            adjusted = ({1'b0, prefix} << 1) + {5'd0, hut} - {1'b0, total};
            // Absolute value
            if (adjusted[13]) begin
                abs_val = -adjusted;
            end else begin
                abs_val = adjusted;
            end
            // Subtract (hut & 1)
            adjusted = abs_val - {13'd0, hut[0]};
            // max(0, ...)
            if (adjusted[13]) begin
                result = 14'd0;
            end else begin
                result = adjusted;
            end
            compute_diff = result;
        end
    endfunction

endmodule