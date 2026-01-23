module ip_remove_leading_zeros (
  input clk,
  input rst_n,
  input start,
  input [119:0] ip_in,
  output reg [119:0] ip_out,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_OCTET,
    STRIP_ZEROS,
    WRITE_OCTET,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [7:0] current_char;
  reg [7:0] octet_buffer [0:3];
  reg [2:0] octet_index = 0;
  reg [3:0] char_index = 0;
  reg [3:0] octet_char_count = 0;
  reg [3:0] leading_zeros = 0;
  reg [3:0] write_index = 0;
  reg [3:0] cycle_count = 0;
  reg [3:0] done_cycle_count = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      octet_index <= 0;
      char_index <= 0;
      octet_char_count <= 0;
      leading_zeros <= 0;
      write_index <= 0;
      cycle_count <= 0;
      done_cycle_count <= 0;
      done <= 0;
      ip_out <= 120'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_OCTET;
            octet_index <= 0;
            char_index <= 0;
            octet_char_count <= 0;
            leading_zeros <= 0;
            write_index <= 0;
            cycle_count <= 0;
            done <= 0;
          end
        end

        READ_OCTET: begin
          current_char = ip_in[(octet_index * 8) +: 8];
          
          if (current_char == 8'h2E || char_index == 3) begin
            // End of octet (dot or max 3 chars)
            if (octet_char_count == 0) begin
              // Empty octet, keep as "0"
              octet_buffer[octet_index] = 8'h30; // '0'
            end
            state <= STRIP_ZEROS;
            char_index <= 0;
          end else begin
            // Store character in buffer
            octet_buffer[octet_index][char_index] = current_char;
            char_index <= char_index + 1;
            octet_char_count <= octet_char_count + 1;
          end
        end

        STRIP_ZEROS: begin
          if (leading_zeros < octet_char_count && octet_buffer[octet_index][leading_zeros] == 8'h30) begin
            leading_zeros <= leading_zeros + 1;
          end else begin
            // Found first non-zero or end of octet
            if (leading_zeros == octet_char_count) begin
              // All zeros, keep one '0'
              octet_buffer[octet_index][0] = 8'h30;
              octet_char_count <= 1;
            end else begin
              // Shift remaining characters left
              for (int i = 0; i < octet_char_count - leading_zeros; i++) begin
                octet_buffer[octet_index][i] = octet_buffer[octet_index][i + leading_zeros];
              end
              octet_char_count <= octet_char_count - leading_zeros;
            end
            state <= WRITE_OCTET;
            leading_zeros <= 0;
          end
        end

        WRITE_OCTET: begin
          if (write_index < octet_char_count) begin
            ip_out[write_index * 8 +: 8] = octet_buffer[octet_index][write_index];
            write_index <= write_index + 1;
          end else begin
            // Add dot if not last octet
            if (octet_index < 3) begin
              ip_out[write_index * 8 +: 8] = 8'h2E; // '.'
              write_index <= write_index + 1;
            end
            
            octet_index <= octet_index + 1;
            write_index <= write_index;
            
            if (octet_index == 4) begin
              state <= DONE;
              cycle_count <= 0;
            end else begin
              state <= READ_OCTET;
              char_index <= 0;
              octet_char_count <= 0;
            end
          end
        end

        DONE: begin
          if (cycle_count < 50) begin
            cycle_count <= cycle_count + 1;
          end else begin
            done <= 1;
          end
        end
      endcase
    end
  end

endmodule