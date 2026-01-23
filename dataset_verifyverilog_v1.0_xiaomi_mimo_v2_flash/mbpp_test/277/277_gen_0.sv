module dict_filter (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input dictionary (fixed size: 4 entries)
    // Each key is 8 characters (8-bit ASCII), packed into 64-bit vectors
    // Each value is 8-bit integer
    input wire [63:0] key_0, key_1, key_2, key_3,
    input wire [7:0]  val_0, val_1, val_2, val_3,
    input wire [7:0]  threshold,
    
    // Output: filtered results
    // Returns up to 4 results, packed similarly
    output reg [63:0] out_key_0, out_key_1, out_key_2, out_key_3,
    output reg [7:0]  out_val_0, out_val_1, out_val_2, out_val_3,
    output reg [2:0]  out_count,
    output reg        done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    
    reg [1:0] state;
    reg [2:0] idx;
    reg [2:0] write_idx;
    reg [2:0] temp_count;
    
    // Temporary storage for filtered results
    reg [63:0] temp_keys_0;
    reg [63:0] temp_keys_1;
    reg [63:0] temp_keys_2;
    reg [63:0] temp_keys_3;
    reg [7:0]  temp_vals_0;
    reg [7:0]  temp_vals_1;
    reg [7:0]  temp_vals_2;
    reg [7:0]  temp_vals_3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_count <= 3'd0;
            out_key_0 <= 64'd0;
            out_key_1 <= 64'd0;
            out_key_2 <= 64'd0;
            out_key_3 <= 64'd0;
            out_val_0 <= 8'd0;
            out_val_1 <= 8'd0;
            out_val_2 <= 8'd0;
            out_val_3 <= 8'd0;
            idx <= 3'd0;
            write_idx <= 3'd0;
            temp_count <= 3'd0;
            temp_keys_0 <= 64'd0;
            temp_keys_1 <= 64'd0;
            temp_keys_2 <= 64'd0;
            temp_keys_3 <= 64'd0;
            temp_vals_0 <= 8'd0;
            temp_vals_1 <= 8'd0;
            temp_vals_2 <= 8'd0;
            temp_vals_3 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        idx <= 3'd0;
                        write_idx <= 3'd0;
                        temp_count <= 3'd0;
                    end
                end
                
                COMPARE: begin
                    if (idx < 4'd4) begin
                        case (idx)
                            3'd0: begin
                                if (val_0 >= threshold) begin
                                    temp_keys_0 <= key_0;
                                    temp_vals_0 <= val_0;
                                    write_idx <= write_idx + 3'd1;
                                    temp_count <= temp_count + 3'd1;
                                end
                            end
                            3'd1: begin
                                if (val_1 >= threshold) begin
                                    temp_keys_1 <= key_1;
                                    temp_vals_1 <= val_1;
                                    write_idx <= write_idx + 3'd1;
                                    temp_count <= temp_count + 3'd1;
                                end
                            end
                            3'd2: begin
                                if (val_2 >= threshold) begin
                                    temp_keys_2 <= key_2;
                                    temp_vals_2 <= val_2;
                                    write_idx <= write_idx + 3'd1;
                                    temp_count <= temp_count + 3'd1;
                                end
                            end
                            3'd3: begin
                                if (val_3 >= threshold) begin
                                    temp_keys_3 <= key_3;
                                    temp_vals_3 <= val_3;
                                    write_idx <= write_idx + 3'd1;
                                    temp_count <= temp_count + 3'd1;
                                end
                            end
                        endcase
                        idx <= idx + 3'd1;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    out_count <= temp_count;
                    out_key_0 <= temp_keys_0;
                    out_val_0 <= temp_vals_0;
                    out_key_1 <= temp_keys_1;
                    out_val_1 <= temp_vals_1;
                    out_key_2 <= temp_keys_2;
                    out_val_2 <= temp_vals_2;
                    out_key_3 <= temp_keys_3;
                    out_val_3 <= temp_vals_3;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule