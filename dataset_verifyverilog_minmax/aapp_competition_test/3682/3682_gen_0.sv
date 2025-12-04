module code_match_detector(
  input clk,
  input rst_n,
  input start,
  input [127:0] line_in,
  input line_valid,
  input fragment_end,
  input end_of_code, // Pulse to finalize and output result
  output reg [2:0] max_count,
  output reg [255:0] filenames,
  output reg done
);

  localparam FRAGMENTS = 2;
  localparam LINES = 4;
  localparam CHARS_PER_LINE = 16;

  typedef struct packed {
    bit [127:0] data;
  } Line;

  typedef struct packed {
    Line line [LINES];
  } Fragment;

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} State;

  State state;

  Fragment fragments;
  bit have_fragment [FRAGMENTS];
  bit [1:0] storing_frag_idx;
  bit storing_enabled;
  bit [2:0] loaded_count [FRAGMENTS];
  bit [2:0] compare_count [FRAGMENTS];
  bit [2:0] consecutive [FRAGMENTS];
  bit [2:0] best_count [FRAGMENTS];
  bit [2:0] best_consecutive;
  bit [2:0] best_index;

  reg [127:0] filename0_r, filename1_r;

  string line_normalized;
  bit line_is_empty;

  function automatic string normalize_line(input [127:0] in_line, output bit is_empty);
    int i;
    string s;
    string t;
    bit all_space;
    s = "";
    t = "";
    all_space = 1'b1;
    for (i = 0; i < CHARS_PER_LINE; i++) begin
      if (in_line[(i*8)+:8] == 8'h00) begin
        break;
      end
      s = {s, string'(in_line[(i*8)+:8])};
    end
    t = s;
    i = 0;
    while (i < t.len()) begin
      if (t[i] == " " || t[i] == "\t" || t[i] == "\r" || t[i] == "\n") begin
        t = t.substr(0, i-1);
        break;
      end
      i++;
    end
    s = t;
    s = s.strip();
    t = "";
    for (i = 0; i < s.len(); i++) begin
      if (s[i] == " " || s[i] == "\t" || s[i] == "\r" || s[i] == "\n") begin
        if ((t.len() > 0) && (t[t.len()-1] != " ")) begin
          t = {t, " "};
        end
      end else begin
        t = {t, s[i]};
      end
    end
    s = t;
    for (i = 0; i < s.len(); i++) begin
      if (s[i] != " ") begin
        all_space = 1'b0;
        break;
      end
    end
    is_empty = all_space || (s.len() == 0);
    return s;
  endfunction

  function automatic bit eq128(input [127:0] a, input [127:0] b);
    return (a == b);
  endfunction

  task load_line;
    input [127:0] line;
    input bit [1:0] frag_idx;
    input bit [2:0] count;
    line_normalized = normalize_line(line, line_is_empty);
    if (line_is_empty == 1'b0) begin
      if (count < LINES) begin
        fragments.line[count].data = 128'(line_normalized);
        have_fragment[frag_idx] = 1'b1;
      end
    end
  endtask

  task compare_line;
    input [127:0] line;
    input bit [1:0] frag_idx;
    input bit [2:0] count;
    line_normalized = normalize_line(line, line_is_empty);
    if ((have_fragment[frag_idx] == 1'b1) && (count < LINES)) begin
      if (line_is_empty == 1'b0) begin
        if (eq128(128'(line_normalized), fragments.line[count].data)) begin
          consecutive[frag_idx] = consecutive[frag_idx] + 1;
        end else begin
          if (consecutive[frag_idx] > best_count[frag_idx]) begin
            best_count[frag_idx] = consecutive[frag_idx];
          end
          consecutive[frag_idx] = 0;
        end
      end
    end
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
      state <= IDLE;
      done <= 1'b0;
      max_count <= 0;
      filenames <= 256'b0;
      fragments <= '{default:'0};
      have_fragment <= '{0, 0};
      storing_frag_idx <= 0;
      storing_enabled <= 1'b1;
      loaded_count <= '{0, 0};
      compare_count <= '{0, 0};
      consecutive <= '{0, 0};
      best_count <= '{0, 0};
      best_consecutive <= 0;
      best_index <= 0;
      filename0_r <= 128'b0;
      filename1_r <= 128'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          max_count <= 0;
          filenames <= 256'b0;
          fragments <= '{default:'0};
          have_fragment <= '{0, 0};
          storing_frag_idx <= 0;
          storing_enabled <= 1'b1;
          loaded_count <= '{0, 0};
          compare_count <= '{0, 0};
          consecutive <= '{0, 0};
          best_count <= '{0, 0};
          best_consecutive <= 0;
          best_index <= 0;
          filename0_r <= 128'b0;
          filename1_r <= 128'b0;
          if (start == 1'b1) begin
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          if (line_valid == 1'b1) begin
            if (storing_enabled == 1'b1) begin
              load_line(line_in, storing_frag_idx, loaded_count[storing_frag_idx]);
              if (line_is_empty == 1'b0) begin
                loaded_count[storing_frag_idx] <= loaded_count[storing_frag_idx] + 1;
              end
              if (fragment_end == 1'b1) begin
                if (storing_frag_idx == 0) begin
                  storing_frag_idx <= 1;
                end else begin
                  storing_enabled <= 1'b0;
                end
              end
            end else begin
              compare_line(line_in, 0, compare_count[0]);
              compare_line(line_in, 1, compare_count[1]);
              if (line_is_empty == 1'b0) begin
                compare_count[0] <= compare_count[0] + 1;
                compare_count[1] <= compare_count[1] + 1;
              end
            end
          end
          if (end_of_code == 1'b1) begin
            if (consecutive[0] > best_count[0]) best_count[0] <= consecutive[0];
            if (consecutive[1] > best_count[1]) best_count[1] <= consecutive[1];
            if (best_count[0] >= best_count[1]) begin
              best_consecutive <= best_count[0];
              best_index <= 0;
            end else begin
              best_consecutive <= best_count[1];
              best_index <= 1;
            end
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1'b1;
          max_count <= best_consecutive;
          if (best_consecutive == 0) begin
            filenames <= {filename1_r, filename0_r};
          end else begin
            if (best_index == 0) begin
              filenames <= {filename0_r, filename1_r};
            end else begin
              filenames <= {filename1_r, filename0_r};
            end
          end
          if (start == 1'b1) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule