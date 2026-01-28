module dict_drop_empty (
    input clk,
    input rst_n,
    input start,
    input [3:0] key_in_0, key_in_1, key_in_2, key_in_3, key_in_4, key_in_5, key_in_6, key_in_7,
    input [7:0] val_in_0, val_in_1, val_in_2, val_in_3, val_in_4, val_in_5, val_in_6, val_in_7,
    input [7:0] valid_in,
    output reg [3:0] key_out_0, key_out_1, key_out_2, key_out_3, key_out_4, key_out_5, key_out_6, key_out_7,
    output reg [7:0] val_out_0, val_out_1, val_out_2, val_out_3, val_out_4, val_out_5, val_out_6, val_out_7,
    output reg [7:0] valid_out,
    output reg [3:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SETUP      = 3'd1;
    localparam [2:0] PROCESS_0  = 3'd2;
    localparam [2:0] PROCESS_1  = 3'd3;
    localparam [2:0] PROCESS_2  = 3'd4;
    localparam [2:0] PROCESS_3  = 3'd5;
    localparam [2:0] PROCESS_4  = 3'd6;
    localparam [2:0] FINISH     = 3'd7;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Input buffer registers
    reg [3:0] key_buf [0:7];
    reg [7:0] val_buf [0:7];
    reg [7:0] valid_buf;
    
    // Processing counters and indices
    reg [2:0] input_idx;        // Current input entry being checked
    reg [3:0] output_idx;       // Current output slot to fill
    reg [3:0] count_temp;       // Temporary count accumulator
    reg [7:0] valid_out_temp;   // Temporary valid output mask
    
    // Temporary output arrays for accumulation
    reg [3:0] temp_key [0:7];
    reg [7:0] temp_val [0:7];
    reg [7:0] temp_valid;
    
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SETUP : IDLE;
            SETUP:      next_state = PROCESS_0;
            PROCESS_0:  next_state = PROCESS_1;
            PROCESS_1:  next_state = PROCESS_2;
            PROCESS_2:  next_state = PROCESS_3;
            PROCESS_3:  next_state = PROCESS_4;
            PROCESS_4:  next_state = FINISH;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            valid_out <= 8'd0;
            
            // Reset input buffers
            for (i = 0; i < 8; i = i + 1) begin
                key_buf[i] <= 4'd0;
                val_buf[i] <= 8'd0;
                temp_key[i] <= 4'd0;
                temp_val[i] <= 8'd0;
            end
            valid_buf <= 8'd0;
            
            // Reset output arrays
            key_out_0 <= 4'd0; key_out_1 <= 4'd0; key_out_2 <= 4'd0; key_out_3 <= 4'd0;
            key_out_4 <= 4'd0; key_out_5 <= 4'd0; key_out_6 <= 4'd0; key_out_7 <= 4'd0;
            val_out_0 <= 8'd0; val_out_1 <= 8'd0; val_out_2 <= 8'd0; val_out_3 <= 8'd0;
            val_out_4 <= 8'd0; val_out_5 <= 8'd0; val_out_6 <= 8'd0; val_out_7 <= 8'd0;
            
            input_idx <= 3'd0;
            output_idx <= 4'd0;
            count_temp <= 4'd0;
            valid_out_temp <= 8'd0;
            temp_valid <= 8'd0;
            
        end else begin
            state <= next_state;
            
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 8'd0;
                    result_count <= 4'd0;
                    input_idx <= 3'd0;
                    output_idx <= 4'd0;
                    count_temp <= 4'd0;
                    valid_out_temp <= 8'd0;
                    temp_valid <= 8'd0;
                end
                
                SETUP: begin
                    // Sample inputs on start
                    key_buf[0] <= key_in_0;
                    key_buf[1] <= key_in_1;
                    key_buf[2] <= key_in_2;
                    key_buf[3] <= key_in_3;
                    key_buf[4] <= key_in_4;
                    key_buf[5] <= key_in_5;
                    key_buf[6] <= key_in_6;
                    key_buf[7] <= key_in_7;
                    
                    val_buf[0] <= val_in_0;
                    val_buf[1] <= val_in_1;
                    val_buf[2] <= val_in_2;
                    val_buf[3] <= val_in_3;
                    val_buf[4] <= val_in_4;
                    val_buf[5] <= val_in_5;
                    val_buf[6] <= val_in_6;
                    val_buf[7] <= val_in_7;
                    
                    valid_buf <= valid_in;
                    
                    // Initialize temp storage
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_key[i] <= 4'd0;
                        temp_val[i] <= 8'd0;
                    end
                    temp_valid <= 8'd0;
                    input_idx <= 3'd0;
                    output_idx <= 4'd0;
                    count_temp <= 4'd0;
                    valid_out_temp <= 8'd0;
                end
                
                PROCESS_0: begin
                    // Check entry 0
                    if (valid_buf[0] && (val_buf[0] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[0];
                        temp_val[output_idx] <= val_buf[0];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[0] <= 1'b1;
                    end
                end
                
                PROCESS_1: begin
                    // Check entry 1
                    if (valid_buf[1] && (val_buf[1] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[1];
                        temp_val[output_idx] <= val_buf[1];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[1] <= 1'b1;
                    end
                end
                
                PROCESS_2: begin
                    // Check entry 2
                    if (valid_buf[2] && (val_buf[2] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[2];
                        temp_val[output_idx] <= val_buf[2];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[2] <= 1'b1;
                    end
                end
                
                PROCESS_3: begin
                    // Check entry 3
                    if (valid_buf[3] && (val_buf[3] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[3];
                        temp_val[output_idx] <= val_buf[3];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[3] <= 1'b1;
                    end
                end
                
                PROCESS_4: begin
                    // Check entries 4-7
                    if (valid_buf[4] && (val_buf[4] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[4];
                        temp_val[output_idx] <= val_buf[4];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[4] <= 1'b1;
                    end
                    
                    if (valid_buf[5] && (val_buf[5] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[5];
                        temp_val[output_idx] <= val_buf[5];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[5] <= 1'b1;
                    end
                    
                    if (valid_buf[6] && (val_buf[6] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[6];
                        temp_val[output_idx] <= val_buf[6];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[6] <= 1'b1;
                    end
                    
                    if (valid_buf[7] && (val_buf[7] != 8'hFF)) begin
                        temp_key[output_idx] <= key_buf[7];
                        temp_val[output_idx] <= val_buf[7];
                        temp_valid[output_idx] <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        count_temp <= count_temp + 4'd1;
                        valid_out_temp[7] <= 1'b1;
                    end
                end
                
                FINISH: begin
                    // Copy temp results to outputs
                    key_out_0 <= temp_key[0];
                    key_out_1 <= temp_key[1];
                    key_out_2 <= temp_key[2];
                    key_out_3 <= temp_key[3];
                    key_out_4 <= temp_key[4];
                    key_out_5 <= temp_key[5];
                    key_out_6 <= temp_key[6];
                    key_out_7 <= temp_key[7];
                    
                    val_out_0 <= temp_val[0];
                    val_out_1 <= temp_val[1];
                    val_out_2 <= temp_val[2];
                    val_out_3 <= temp_val[3];
                    val_out_4 <= temp_val[4];
                    val_out_5 <= temp_val[5];
                    val_out_6 <= temp_val[6];
                    val_out_7 <= temp_val[7];
                    
                    valid_out <= temp_valid;
                    result_count <= count_temp;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result_count <= 4'd0;
                    valid_out <= 8'd0;
                end
            endcase
        end
    end

endmodule