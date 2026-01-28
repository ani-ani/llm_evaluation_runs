module dict_filter (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input dictionary (fixed size: 4 entries)
    input wire [63:0] key_0, key_1, key_2, key_3,
    input wire [7:0]  val_0, val_1, val_2, val_3,
    input wire [7:0]  threshold,
    
    // Output: filtered results
    output reg [63:0] out_key_0, out_key_1, out_key_2, out_key_3,
    output reg [7:0]  out_val_0, out_val_1, out_val_2, out_val_3,
    output reg [2:0]  out_count,
    output reg        done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] OUTPUT    = 2'd2;
    
    reg [1:0] state;
    
    // Filtered storage
    reg [63:0] temp_keys [0:3];
    reg [7:0]  temp_vals [0:3];
    reg [2:0]  temp_count;
    integer i; // For loop index
    
    // Combinational processing
    always @(*) begin
        temp_count = 3'd0;
        
        // Initialize temp arrays to prevent latches
        for (i = 0; i < 4; i = i + 1) begin
            temp_keys[i] = 64'd0;
            temp_vals[i] = 8'd0;
        end
        
        // Process inputs in order
        if (val_0 >= threshold) begin
            temp_keys[temp_count] = key_0;
            temp_vals[temp_count] = val_0;
            temp_count = temp_count + 3'd1;
        end
        if (val_1 >= threshold) begin
            temp_keys[temp_count] = key_1;
            temp_vals[temp_count] = val_1;
            temp_count = temp_count + 3'd1;
        end
        if (val_2 >= threshold) begin
            temp_keys[temp_count] = key_2;
            temp_vals[temp_count] = val_2;
            temp_count = temp_count + 3'd1;
        end
        if (val_3 >= threshold) begin
            temp_keys[temp_count] = key_3;
            temp_vals[temp_count] = val_3;
            temp_count = temp_count + 3'd1;
        end
    end
    
    // State transition
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
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Update outputs with combinatorial results
                    out_key_0 <= temp_keys[0];
                    out_key_1 <= temp_keys[1];
                    out_key_2 <= temp_keys[2];
                    out_key_3 <= temp_keys[3];
                    out_val_0 <= temp_vals[0];
                    out_val_1 <= temp_vals[1];
                    out_val_2 <= temp_vals[2];
                    out_val_3 <= temp_vals[3];
                    out_count <= temp_count;
                    
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule